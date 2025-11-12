# Importa tutti gli ambienti Conda da file YAML
<#
.SYNOPSIS
    Importa e aggiorna ambienti Conda da file YAML con gestione timeout per ambienti problematici

.DESCRIPTION
    Questo script importa o aggiorna ambienti Conda da file YAML nella directory specificata.
    Analizza automaticamente ogni file YAML per determinare la complessità e applica gestione
    speciale (timeout + solver libmamba) per ambienti complessi che potrebbero bloccarsi
    durante la risoluzione delle dipendenze.

.PARAMETER ImportDir
    Directory contenente i file YAML degli ambienti. Default: "conda_env_exports"

.PARAMETER TimeoutSeconds
    Timeout in secondi per ambienti complessi rilevati automaticamente. Default: 600 (10 minuti)

.EXAMPLE
    .\import_conda_envs.ps1
    Importa tutti gli ambienti con impostazioni predefinite

.EXAMPLE
    .\import_conda_envs.ps1 -TimeoutSeconds 300
    Importa con timeout di 5 minuti per ambienti complessi

.EXAMPLE
    .\import_conda_envs.ps1 -ImportDir "my_envs" -TimeoutSeconds 1200
    Importa da directory personalizzata con timeout di 20 minuti

.NOTES
    - Rileva automaticamente Anaconda/Miniconda installato nel sistema
    - Analisi automatica della complessità dei file YAML
    - Usa solver libmamba e timeout per ambienti complessi
    - Genera un riepilogo dettagliato al termine con analisi della complessità
    - Supporta installazioni in posizioni standard e personalizzate
#>

param(
    [string]$ImportDir = "conda_env_exports",
    [int]$TimeoutSeconds = 600
)

# Specifica la cartella contenente i file YAML
$importDir = $ImportDir

# Verifica se la cartella esiste
if (-Not (Test-Path -Path $importDir)) {
    Write-Error "La cartella $importDir non esiste."
    exit
}

# Funzione per trovare dinamicamente l'installazione di Anaconda/Miniconda
function Find-CondaPython {
    $possiblePaths = @(
        # Anaconda installazioni standard
        "C:\ProgramData\Anaconda3\python.exe",
        "C:\ProgramData\Anaconda\python.exe", 
        "C:\Anaconda3\python.exe",
        "C:\Anaconda\python.exe",
        
        # Miniconda installazioni standard
        "C:\ProgramData\Miniconda3\python.exe",
        "C:\ProgramData\Miniconda\python.exe",
        "C:\Miniconda3\python.exe", 
        "C:\Miniconda\python.exe",
        
        # Installazioni utente
        "$env:USERPROFILE\Anaconda3\python.exe",
        "$env:USERPROFILE\Miniconda3\python.exe",
        "$env:USERPROFILE\AppData\Local\Continuum\anaconda3\python.exe",
        "$env:USERPROFILE\AppData\Local\Continuum\miniconda3\python.exe"
    )
    
    # Prova anche da variabili d'ambiente
    if ($env:CONDA_PREFIX) {
        $possiblePaths += "$env:CONDA_PREFIX\python.exe"
    }
    if ($env:CONDA_EXE) {
        $condaDir = Split-Path $env:CONDA_EXE -Parent
        $possiblePaths += "$condaDir\python.exe"
    }
    
    # Cerca python usando where.exe per trovare installazioni nel PATH
    try {
        $whereResults = where.exe python 2>$null
        if ($whereResults) {
            foreach ($pythonPath in $whereResults) {
                if (Test-Path $pythonPath) {
                    $possiblePaths += $pythonPath
                }
            }
        }
    }
    catch {
        # Ignora errori di where.exe
    }
    
    # Cerca anche python.exe usando where.exe
    try {
        $wherePythonExe = where.exe python.exe 2>$null
        if ($wherePythonExe) {
            foreach ($pythonExePath in $wherePythonExe) {
                if (Test-Path $pythonExePath) {
                    $possiblePaths += $pythonExePath
                }
            }
        }
    }
    catch {
        # Ignora errori di where.exe per python.exe
    }
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            # Verifica che supporti conda
            try {
                $result = & $path -m conda --version 2>$null
                if ($result) {
                    return $path
                }
            }
            catch {
                continue
            }
        }
    }
    
    # Ultimo tentativo: cerca conda nel PATH usando Get-Command
    try {
        $condaCmd = Get-Command conda -ErrorAction SilentlyContinue
        if ($condaCmd) {
            $condaPath = $condaCmd.Source
            $condaDir = Split-Path $condaPath -Parent
            $pythonPath = Join-Path $condaDir "python.exe"
            if (Test-Path $pythonPath) {
                return $pythonPath
            }
        }
    }
    catch {
        # Ignora errori
    }
    
    return $null
}

# Trova dinamicamente l'installazione di Anaconda/Miniconda
$anacondaPython = Find-CondaPython
try {
    if ($anacondaPython) {
        $condaVersion = & $anacondaPython -m conda --version 2>$null
        Write-Output "Conda disponibile: $condaVersion"
        Write-Output "Usando Python da: $anacondaPython"
    }
    else {
        throw "Nessuna installazione di Anaconda/Miniconda trovata"
    }
}
catch {
    Write-Error "Conda non è disponibile. Errore: $_"
    Write-Error "Assicurati che Anaconda o Miniconda sia installato correttamente."
    exit
}

# Funzione per verificare se un ambiente Conda esiste
function Test-CondaEnvironment {
    param($EnvName)
    # Usa il percorso dinamico di Python per evitare problemi di PATH
    $envList = & $script:anacondaPython -m conda env list 2>$null
    return $envList | Select-String -Pattern "^\s*$EnvName\s" -Quiet
}

# Funzione per eseguire comandi conda con timeout e opzioni speciali per ambienti problematici
function Invoke-CondaWithTimeout {
    param(
        [string]$EnvName,
        [string]$YamlFile,
        [string]$Operation,  # "create" o "update"
        [string]$EnvPath = "",
        [int]$TimeoutSeconds = $script:TimeoutSeconds
    )
    
    try {
        # Usa il percorso Python trovato dinamicamente
        $pythonPath = $script:anacondaPython
        
        # Costruisci il comando base
        $cmdArgs = @()
        if ($Operation -eq "create") {
            $cmdArgs += "env", "create", "-f", $YamlFile
            if ($EnvPath) {
                $cmdArgs += "--prefix", $EnvPath
            }
            else {
                $cmdArgs += "-n", $EnvName
            }
        }
        elseif ($Operation -eq "update") {
            $cmdArgs += "env", "update", "-n", $EnvName, "-f", $YamlFile
        }
        else {
            throw "Operazione non supportata: $Operation"
        }
        
        # Aggiungi opzioni speciali per ambienti problematici
        $cmdArgs += "--solver=libmamba"
        
        Write-Output "Esecuzione comando (timeout: ${TimeoutSeconds}s): conda $($cmdArgs -join ' ')"
        
        # Crea un job per eseguire il comando con timeout
        $job = Start-Job -ScriptBlock {
            param($PythonPath, $CmdArgs)
            & $PythonPath -m conda @CmdArgs
        } -ArgumentList $pythonPath, $cmdArgs
        
        # Attendi il completamento o timeout
        $completed = Wait-Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $jobState = $job.State
            Receive-Job $job | Out-Null  # Consuma l'output senza memorizzarlo
            Remove-Job $job
            
            if ($jobState -eq "Completed") {
                Write-Output "Comando completato con successo"
                return $true
            }
            else {
                Write-Error "Il job è terminato con stato: $jobState"
                return $false
            }
        }
        else {
            # Timeout raggiunto
            Write-Warning "Timeout raggiunto (${TimeoutSeconds}s) per l'ambiente $EnvName"
            Stop-Job $job
            Remove-Job $job
            return $false
        }
    }
    catch {
        Write-Error "Errore durante l'esecuzione del comando conda per $EnvName`: $_"
        return $false
    }
}

# Funzione per analizzare se un ambiente YAML richiede gestione speciale
function Test-RequiresSpecialHandling {
    param([string]$YamlFilePath)
    
    try {
        $content = Get-Content $YamlFilePath -Raw
        
        # Criteri che indicano un ambiente potenzialmente problematico:
        
        # 1. Molte dipendenze (>20)
        $dependencies = ($content | Select-String -Pattern '^\s*-\s+\w+' -AllMatches).Matches.Count
        if ($dependencies -gt 20) {
            return $true, "Molte dipendenze ($dependencies)"
        }
        
        # 2. Canali non standard o multipli canali complessi
        $channels = ($content | Select-String -Pattern '^\s*-\s+[^d]' -AllMatches).Matches.Count
        $hasComplexChannels = $content -match 'conda-forge.*defaults.*' -or 
        $content -match 'https?://' -or
        $channels -gt 3
        if ($hasComplexChannels) {
            return $true, "Canali complessi o multipli"
        }
        
        # 3. Versioni Python molto specifiche o vecchie
        if ($content -match 'python\s*=\s*[23]\.[0-6]' -or $content -match 'python\s*=\s*\d+\.\d+\.\d+') {
            return $true, "Versione Python specifica/legacy"
        }
        
        # 4. Pacchetti noti per essere problematici
        $problematicPackages = @('tensorflow', 'pytorch', 'opencv', 'vtk', 'itk', 'gdal', 'geopandas', 'cartopy', 'dask')
        foreach ($pkg in $problematicPackages) {
            if ($content -match "^\s*-\s+$pkg") {
                return $true, "Contiene pacchetto problematico: $pkg"
            }
        }
        
        # 5. Pip dependencies (spesso causano conflitti)
        if ($content -match '^\s*-\s+pip\s*:' -or $content -match '^\s*pip\s*:') {
            return $true, "Contiene dipendenze pip"
        }
        
        # 6. Dimensione file molto grande (>2KB indica complessità)
        $fileSize = (Get-Item $YamlFilePath).Length
        if ($fileSize -gt 2048) {
            return $true, "File YAML molto grande (${fileSize} bytes)"
        }
        
        return $false, "Standard"
    }
    catch {
        # In caso di errore nell'analisi, considera come potenzialmente problematico
        return $true, "Errore nell'analisi: $_"
    }
}

Write-Output "=== Importazione Ambienti Conda ==="
Write-Output "Directory di importazione: $importDir"
Write-Output "Timeout per ambienti complessi: ${TimeoutSeconds}s"
Write-Output "Analisi automatica della complessità degli ambienti attivata"
Write-Output ""

# Contatori e tracciamento dettagliato per il riepilogo
$totalEnvironments = 0
$successfulEnvironments = 0
$failedEnvironments = @()
$timeoutEnvironments = @()
$complexEnvironments = @()
$standardEnvironments = @()

# Tracciamento dettagliato per il riepilogo finale
$environmentResults = @{}  # Hash table per tracciare risultati dettagliati
$createdEnvironments = @()
$updatedEnvironments = @()
$errorDetails = @{}

# Importa ogni file YAML come ambiente Conda
$userProfile = [System.Environment]::GetFolderPath("UserProfile")
$envsRootPath = Join-Path -Path $userProfile -ChildPath ".conda\envs\"
$yamlFiles = Get-ChildItem -Path $importDir -Filter *.yml

foreach ($file in $yamlFiles) {
    $envName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $envPath = Join-Path -Path $envsRootPath -ChildPath $envName
    $totalEnvironments++
    
    # Analizza se l'ambiente richiede gestione speciale
    $requiresSpecialHandling, $reason = Test-RequiresSpecialHandling -YamlFilePath $file.FullName
    
    if ($requiresSpecialHandling) {
        Write-Output "Ambiente '$envName': COMPLESSO - $reason"
        $complexEnvironments += $envName
    }
    else {
        Write-Output "Ambiente '$envName': STANDARD - $reason"
        $standardEnvironments += $envName
    }
    
    # Verifica se l'ambiente esiste già
    if (Test-CondaEnvironment -EnvName $envName) {
        Write-Output "L'ambiente '$envName' esiste già. Aggiornamento in corso..."
        try {
            # Usa la funzione con timeout per gli ambienti complessi
            if ($requiresSpecialHandling) {
                Write-Output "Usando gestione speciale per ambiente complesso '$envName'"
                $success = Invoke-CondaWithTimeout -EnvName $envName -YamlFile $file.FullName -Operation "update"
                if (-not $success) {
                    Write-Error "Timeout o errore durante l'aggiornamento dell'ambiente complesso '$envName'"
                    $timeoutEnvironments += $envName
                    $environmentResults[$envName] = @{
                        Status    = "TIMEOUT"
                        Operation = "Update"
                        Type      = "Complex"
                        Error     = "Timeout durante aggiornamento ambiente complesso"
                    }
                    continue
                }
                else {
                    $successfulEnvironments++
                    $updatedEnvironments += $envName
                    $environmentResults[$envName] = @{
                        Status    = "SUCCESS"
                        Operation = "Update"
                        Type      = "Complex"
                        Error     = $null
                    }
                }
            }
            else {
                # Prima aggiorna l'ambiente usando conda dall'ambiente base
                $updateResult = & $anacondaPython -m conda env update -n $envName -f $file.FullName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Errore conda: $updateResult"
                }
                $successfulEnvironments++
                $updatedEnvironments += $envName
                $environmentResults[$envName] = @{
                    Status    = "SUCCESS"
                    Operation = "Update"
                    Type      = "Standard"
                    Error     = $null
                }
            }
            
            # Aggiorna pip usando il percorso diretto dell'ambiente
            Write-Output "Aggiornamento pip nell'ambiente '$envName'..."
            try {
                $envPythonPath = Join-Path -Path $envPath -ChildPath "python.exe"
                if (Test-Path $envPythonPath) {
                    & $envPythonPath -m pip install --upgrade pip 2>$null
                    Write-Output "Pip aggiornato con successo"
                }
                else {
                    Write-Warning "Python non trovato nell'ambiente $envName, salto aggiornamento pip"
                }
            }
            catch {
                Write-Warning "Errore durante l'aggiornamento pip: $_"
            }
            
            Write-Output "Aggiornato l'ambiente $envName da $file"
        }
        catch {
            Write-Error "Errore durante l'aggiornamento dell'ambiente $envName`: $_"
            $failedEnvironments += $envName
            $errorDetails[$envName] = $_.Exception.Message
            $environmentResults[$envName] = @{
                Status    = "FAILED"
                Operation = "Update"
                Type      = if ($requiresSpecialHandling) { "Complex" } else { "Standard" }
                Error     = $_.Exception.Message
            }
        }
    }
    else {
        Write-Output "Creazione nuovo ambiente $envName da $file"
        try {
            # Usa la funzione con timeout per gli ambienti complessi
            if ($requiresSpecialHandling) {
                Write-Output "Usando gestione speciale per ambiente complesso '$envName'"
                $success = Invoke-CondaWithTimeout -EnvName $envName -YamlFile $file.FullName -Operation "create" -EnvPath $envPath
                if (-not $success) {
                    Write-Error "Timeout o errore durante la creazione dell'ambiente complesso '$envName'"
                    $timeoutEnvironments += $envName
                    $environmentResults[$envName] = @{
                        Status    = "TIMEOUT"
                        Operation = "Create"
                        Type      = "Complex"
                        Error     = "Timeout durante creazione ambiente complesso"
                    }
                    continue
                }
                else {
                    $successfulEnvironments++
                    $createdEnvironments += $envName
                    $environmentResults[$envName] = @{
                        Status    = "SUCCESS"
                        Operation = "Create"
                        Type      = "Complex"
                        Error     = $null
                    }
                }
            }
            else {
                # Crea un nuovo ambiente
                $createResult = & $anacondaPython -m conda env create -f $file.FullName --prefix $envPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Errore conda: $createResult"
                }
                $successfulEnvironments++
                $createdEnvironments += $envName
                $environmentResults[$envName] = @{
                    Status    = "SUCCESS"
                    Operation = "Create"
                    Type      = "Standard"
                    Error     = $null
                }
            }
            
            # Aggiorna pip nel nuovo ambiente usando il percorso diretto
            Write-Output "Configurazione finale dell'ambiente '$envName'..."
            try {
                $envPythonPath = Join-Path -Path $envPath -ChildPath "python.exe"
                if (Test-Path $envPythonPath) {
                    & $envPythonPath -m pip install --upgrade pip 2>$null
                    Write-Output "Pip aggiornato nel nuovo ambiente"
                }
                else {
                    Write-Warning "Python non trovato nel nuovo ambiente $envName"
                }
            }
            catch {
                Write-Warning "Errore durante l'aggiornamento pip nel nuovo ambiente: $_"
            }
            
            Write-Output "Creato l'ambiente $envName da $file"
        }
        catch {
            Write-Error "Errore durante la creazione dell'ambiente $envName`: $_"
            $failedEnvironments += $envName
            $errorDetails[$envName] = $_.Exception.Message
            $environmentResults[$envName] = @{
                Status    = "FAILED"
                Operation = "Create"
                Type      = if ($requiresSpecialHandling) { "Complex" } else { "Standard" }
                Error     = $_.Exception.Message
            }
        }
    }
}

# Riepilogo finale dettagliato
Write-Output ""
Write-Output "════════════════════════════════════════════════════════════════"
Write-Output "                    RIEPILOGO DETTAGLIATO IMPORTAZIONE"
Write-Output "════════════════════════════════════════════════════════════════"
Write-Output ""
Write-Output "📊 STATISTICHE GENERALI:"
Write-Output "   • Totale ambienti processati: $totalEnvironments"
Write-Output "   • ✅ Completati con successo: $successfulEnvironments"
Write-Output "   • ❌ Falliti: $($failedEnvironments.Count)"
Write-Output "   • ⏰ Timeout: $($timeoutEnvironments.Count)"
Write-Output "   • 📈 Tasso di successo: $(if ($totalEnvironments -gt 0) { [math]::Round(($successfulEnvironments / $totalEnvironments) * 100, 1) } else { 0 })%"
Write-Output ""
Write-Output "🔧 ANALISI PER COMPLESSITÀ:"
Write-Output "   • 📝 Ambienti standard: $($standardEnvironments.Count)"
Write-Output "   • 🔬 Ambienti complessi: $($complexEnvironments.Count)"
Write-Output ""
Write-Output "⚡ OPERAZIONI ESEGUITE:"
Write-Output "   • 🆕 Nuovi ambienti creati: $($createdEnvironments.Count)"
Write-Output "   • 🔄 Ambienti aggiornati: $($updatedEnvironments.Count)"

# Dettaglio ambienti creati con successo
if ($createdEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "🆕 NUOVI AMBIENTI CREATI CON SUCCESSO:"
    foreach ($env in $createdEnvironments) {
        $result = $environmentResults[$env]
        Write-Output "   ✅ $env (Tipo: $($result.Type))"
    }
}

# Dettaglio ambienti aggiornati con successo
if ($updatedEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "🔄 AMBIENTI AGGIORNATI CON SUCCESSO:"
    foreach ($env in $updatedEnvironments) {
        $result = $environmentResults[$env]
        Write-Output "   ✅ $env (Tipo: $($result.Type))"
    }
}

# Dettaglio ambienti falliti con diagnosi errori
if ($failedEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "❌ AMBIENTI FALLITI - DIAGNOSI ERRORI:"
    foreach ($env in $failedEnvironments) {
        $result = $environmentResults[$env]
        Write-Output "   ❌ $env (Operazione: $($result.Operation), Tipo: $($result.Type))"
        
        # Analizza il tipo di errore per fornire suggerimenti specifici
        $error = $result.Error
        Write-Output "      💡 Errore: $error"
        
        # Suggerimenti basati sul tipo di errore
        if ($error -match "conflict|incompatible|version") {
            Write-Output "      🔧 Suggerimento: Conflitto di versioni delle dipendenze"
            Write-Output "         • Controlla il file YAML per versioni incompatibili"
            Write-Output "         • Prova: conda env create -f $env.yml --force-reinstall"
        }
        elseif ($error -match "channel|repository") {
            Write-Output "      🔧 Suggerimento: Problemi con i canali conda"
            Write-Output "         • Verifica la connessione internet"
            Write-Output "         • Prova: conda clean --all && conda update conda"
        }
        elseif ($error -match "package.*not found|404") {
            Write-Output "      🔧 Suggerimento: Pacchetti non trovati"
            Write-Output "         • Alcuni pacchetti potrebbero essere obsoleti"
            Write-Output "         • Modifica il file YAML rimuovendo versioni specifiche"
        }
        elseif ($error -match "permission|access|denied") {
            Write-Output "      🔧 Suggerimento: Problemi di permessi"
            Write-Output "         • Esegui PowerShell come Amministratore"
            Write-Output "         • Controlla i permessi della cartella .conda"
        }
        else {
            Write-Output "      🔧 Suggerimento: Errore generico"
            Write-Output "         • Prova ricreazione manuale: conda env create -f conda_env_exports\\$env.yml"
        }
        Write-Output ""
    }
}

# Dettaglio ambienti timeout
if ($timeoutEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "⏰ AMBIENTI CON TIMEOUT - RISOLUZIONE PROBLEMI:"
    foreach ($env in $timeoutEnvironments) {
        $result = $environmentResults[$env]
        Write-Output "   ⏰ $env (Operazione: $($result.Operation), Tipo: $($result.Type))"
    }
    Write-Output ""
    Write-Output "   🛠️ STRATEGIE DI RISOLUZIONE:"
    Write-Output "   1️⃣ Aumenta timeout: .\import_conda_envs.ps1 -TimeoutSeconds 1800 (30 min)"
    Write-Output "   2️⃣ Risoluzione manuale sequenziale:"
    foreach ($env in $timeoutEnvironments) {
        Write-Output "      conda env create -f conda_env_exports\\$env.yml --solver=libmamba --verbose"
    }
    Write-Output "   3️⃣ Semplificazione YAML: rimuovi versioni specifiche dei pacchetti"
    Write-Output "   4️⃣ Partizionamento: installa prima i pacchetti base, poi aggiungi quelli specifici"
}

# Classificazione per complessità con dettagli
if ($standardEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "📝 AMBIENTI STANDARD (Gestione normale):"
    foreach ($env in $standardEnvironments) {
        $result = $environmentResults[$env]
        $status = switch ($result.Status) {
            "SUCCESS" { "✅" }
            "FAILED" { "❌" }
            "TIMEOUT" { "⏰" }
            default { "❓" }
        }
        Write-Output "   $status $env ($($result.Operation))"
    }
}

if ($complexEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "🔬 AMBIENTI COMPLESSI (Gestione speciale con timeout + libmamba):"
    foreach ($env in $complexEnvironments) {
        $result = $environmentResults[$env]
        $status = switch ($result.Status) {
            "SUCCESS" { "✅" }
            "FAILED" { "❌" }
            "TIMEOUT" { "⏰" }
            default { "❓" }
        }
        Write-Output "   $status $env ($($result.Operation))"
    }
}

# Raccomandazioni generali basate sui risultati
Write-Output ""
Write-Output "💡 RACCOMANDAZIONI GENERALI:"

if ($failedEnvironments.Count -gt 0 -or $timeoutEnvironments.Count -gt 0) {
    Write-Output ""
    Write-Output "🔧 PER RISOLVERE PROBLEMI COMUNI:"
    Write-Output "   • Aggiorna conda: conda update conda"
    Write-Output "   • Pulisci cache: conda clean --all"
    Write-Output "   • Verifica spazio disco: almeno 2GB liberi per ambiente"
    Write-Output "   • Controlla connessione ai repository conda"
    
    if ($failedEnvironments.Count -gt 2) {
        Write-Output ""
        Write-Output "⚠️  MOLTI ERRORI RILEVATI:"
        Write-Output "   • Considera di aggiornare prima conda: conda update -n base conda"
        Write-Output "   • Verifica la configurazione dei canali: conda config --show channels"
        Write-Output "   • Prova reinstallazione di Anaconda/Miniconda se i problemi persistono"
    }
}
else {
    Write-Output "   🎉 Tutte le importazioni sono andate a buon fine!"
    Write-Output "   🔍 Verifica gli ambienti con: conda env list"
}

# Salva rapporto dettagliato su file
$reportPath = "import_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$report = @"
RAPPORTO IMPORTAZIONE AMBIENTI CONDA
====================================
Data: $(Get-Date)
Totale ambienti: $totalEnvironments
Successi: $successfulEnvironments
Falliti: $($failedEnvironments.Count)
Timeout: $($timeoutEnvironments.Count)

DETTAGLI:
$(
foreach ($env in $environmentResults.Keys | Sort-Object) {
    $result = $environmentResults[$env]
    "$env`: $($result.Status) - $($result.Operation) ($($result.Type))"
    if ($result.Error) { "  Errore: $($result.Error)" }
}
)
"@

try {
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Output ""
    Write-Output "📄 Rapporto dettagliato salvato in: $reportPath"
}
catch {
    Write-Warning "Impossibile salvare il rapporto: $_"
}

# Ripristina l'ambiente base di conda
Write-Output ""
Write-Output "🔄 Ripristino ambiente base di conda..."
try {
    & $anacondaPython -m conda activate base 2>$null
    Write-Output "   ✅ Ambiente base ripristinato correttamente"
}
catch {
    Write-Warning "   ⚠️ Non è stato possibile ripristinare l'ambiente base: $_"
    Write-Output "   🔧 Per ripristinare manualmente: conda activate base"
}

Write-Output ""
Write-Output "════════════════════════════════════════════════════════════════"
Write-Output "                       IMPORTAZIONE COMPLETATA!"
Write-Output "════════════════════════════════════════════════════════════════"