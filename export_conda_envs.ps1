# Esporta tutti gli ambienti Conda in file YAML
<#
.SYNOPSIS
    Esporta tutti gli ambienti Conda in file YAML con rilevamento automatico di Anaconda/Miniconda

.DESCRIPTION
    Questo script esporta tutti gli ambienti Conda disponibili nel sistema in file YAML.
    Rileva automaticamente l'installazione di Anaconda/Miniconda e salva ogni ambiente
    in un file separato nella cartella conda_env_exports.

.EXAMPLE
    .\export_conda_envs.ps1
    Esporta tutti gli ambienti in file YAML

.NOTES
    - Rileva automaticamente Anaconda/Miniconda installato nel sistema
    - Esclude l'ambiente base dall'esportazione
    - Crea automaticamente la cartella conda_env_exports
    - Supporta installazioni in posizioni standard e personalizzate
#>

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
        Write-Output "=== Esportazione Ambienti Conda ==="
        Write-Output "Conda disponibile: $condaVersion"
        Write-Output "Usando Python da: $anacondaPython"
        Write-Output ""
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

# Ottieni la lista degli ambienti Conda
Write-Output "🔍 Ricerca ambienti conda disponibili..."
$envList = & $anacondaPython -m conda env list 2>$null

if (-not $envList) {
    Write-Error "Impossibile ottenere la lista degli ambienti conda."
    exit
}

# Estrai i nomi degli ambienti (escludendo base e righe di commento)
$envs = @()
foreach ($line in $envList) {
    if ($line -match '^\s*([^\s#]+)\s+' -and $Matches[1] -ne "base" -and $line -notmatch '^#') {
        $envName = $Matches[1].Trim()
        if ($envName -and $envName -ne "base") {
            $envs += $envName
        }
    }
}

if ($envs.Count -eq 0) {
    Write-Output "ℹ Nessun ambiente conda da esportare (oltre a base)."
    exit
}

Write-Output "📋 Trovati $($envs.Count) ambienti da esportare:"
foreach ($env in $envs) {
    Write-Output "  • $env"
}
Write-Output ""

# Crea una cartella per salvare i file YAML
$exportDir = "conda_env_exports"
if (-Not (Test-Path -Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir | Out-Null
    Write-Output "📁 Creata cartella: $exportDir"
}
else {
    Write-Output "📁 Utilizzando cartella esistente: $exportDir"
}
Write-Output ""

$successCount = 0
$errorCount = 0

# Esporta ogni ambiente in un file YAML
Write-Output "🚀 Avvio esportazione ambienti..."
Write-Output ""

foreach ($env in $envs) {
    $fileName = "$exportDir\$env.yml"
    Write-Output "📦 Esportazione ambiente: $env"
    
    try {
        & $anacondaPython -m conda env export -n $env -f $fileName 2>$null
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $fileName)) {
            $fileSize = (Get-Item $fileName).Length
            Write-Output "  ✅ Esportato in $fileName ($fileSize bytes)"
            $successCount++
        }
        else {
            Write-Warning "  ⚠ Errore durante l'esportazione di $env"
            $errorCount++
        }
    }
    catch {
        Write-Error "  ❌ Errore durante l'esportazione di $env`: $_"
        $errorCount++
    }
}

Write-Output ""
Write-Output "=== RIEPILOGO ESPORTAZIONE ==="
Write-Output "✅ Ambienti esportati con successo: $successCount"
if ($errorCount -gt 0) {
    Write-Output "❌ Ambienti con errori: $errorCount"
}
Write-Output "📁 File salvati in: $exportDir"
Write-Output "📅 Completato: $(Get-Date)"
Write-Output ""
Write-Output "💡 I file YAML possono essere usati con .\import_conda_envs.ps1 per ricreare gli ambienti"