# Aggiorna tutti gli ambienti Conda registrati
<#
.SYNOPSIS
    Aggiorna tutti gli ambienti Conda con rilevamento automatico di Anaconda/Miniconda

.DESCRIPTION
    Questo script aggiorna tutti gli ambienti Conda disponibili nel sistema.
    Rileva automaticamente l'installazione di Anaconda/Miniconda e offre
    opzioni configurabili per l'aggiornamento di Python.

.PARAMETER PythonUpdate
    Modalità di aggiornamento Python:
    yes   : Aggiorna Python automaticamente in tutti gli ambienti
    no    : NON aggiornare Python in nessun ambiente  
    ask   : Chiedi conferma per ogni ambiente
    (vuoto): NON aggiornare Python (comportamento predefinito)

.EXAMPLE
    .\update_conda_envs.ps1
    Aggiorna tutti gli ambienti senza toccare Python

.EXAMPLE
    .\update_conda_envs.ps1 -PythonUpdate yes
    Aggiorna tutti gli ambienti incluso Python automaticamente

.EXAMPLE
    .\update_conda_envs.ps1 -PythonUpdate ask
    Chiede conferma per ogni aggiornamento Python

.NOTES
    - Rileva automaticamente Anaconda/Miniconda installato nel sistema
    - Aggiorna anche l'ambiente base
    - Esegue pulizia automatica al termine
    - Ripristina l'ambiente base al completamento
    - Supporta installazioni in posizioni standard e personalizzate
#>

param(
	[Parameter(Mandatory = $false)]
	[ValidateSet("yes", "no", "ask")]
	[string]$PythonUpdate = ""
)

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

Write-Output "=== Script di Aggiornamento Ambienti Conda ==="
Write-Output "Data: $(Get-Date)"
Write-Output ""
Write-Output "💡 Utilizzo: .\update_conda_envs.ps1 [-PythonUpdate <opzione>]"
Write-Output "   Opzioni per Python:"
Write-Output "   yes   : Aggiorna Python automaticamente in tutti gli ambienti"
Write-Output "   no    : NON aggiornare Python in nessun ambiente"
Write-Output "   ask   : Chiedi conferma per ogni ambiente"
Write-Output "   (vuoto): NON aggiornare Python (comportamento predefinito)"

# Determina la modalità di aggiornamento Python
$pythonUpdateMode = "none"
switch ($PythonUpdate) {
	"yes" { 
		$pythonUpdateMode = "always"
		Write-Output "🐍 Modalità Python: Aggiornamento automatico di Python in tutti gli ambienti"
	}
	"no" { 
		$pythonUpdateMode = "never"
		Write-Output "🐍 Modalità Python: Python NON verrà aggiornato"
	}
	"ask" { 
		$pythonUpdateMode = "ask"
		Write-Output "🐍 Modalità Python: Richiesta conferma per ogni ambiente"
	}
	default { 
		$pythonUpdateMode = "none"
		Write-Output "🐍 Modalità Python: Nessun aggiornamento Python (default)"
	}
}
Write-Output ""

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

# Funzione per gestire l'aggiornamento di Python in un ambiente
function Update-PythonInEnvironment {
	param(
		[string]$EnvName,
		[string]$Mode
	)
	
	if ($Mode -eq "none" -or $Mode -eq "never") {
		return $false
	}
	
	if ($Mode -eq "always") {
		return $true
	}
	
	if ($Mode -eq "ask") {
		$response = Read-Host "  🐍 Vuoi aggiornare Python nell'ambiente '$EnvName'? (s/N)"
		return ($response -match '^[sS]')
	}
	
	return $false
}

# Funzione per verificare se un ambiente Conda esiste
function Test-CondaEnvironment {
	param($EnvName)
	# Usa il percorso dinamico di Python per evitare problemi di PATH
	$envList = & $script:anacondaPython -m conda env list 2>$null
	return $envList | Select-String -Pattern "^\s*$EnvName\s" -Quiet
}



# Funzione per aggiornare un singolo ambiente
function Update-CondaEnvironment {
	param(
		[string]$EnvName,
		[string]$PythonUpdateMode
	)
    
	Write-Output "📦 Aggiornamento ambiente: $EnvName"
	$userProfile = [System.Environment]::GetFolderPath("UserProfile")
	$envPath = Join-Path -Path $userProfile -ChildPath ".conda\envs\$EnvName"
	$envPython = Join-Path -Path $envPath -ChildPath "python.exe"
    
	try {
		# Aggiorna Python se richiesto
		if (Update-PythonInEnvironment -EnvName $EnvName -Mode $PythonUpdateMode) {
			Write-Output "  → Aggiornamento Python..."
			try {
				& $script:anacondaPython -m conda update -n $EnvName python -y 2>$null
				if ($LASTEXITCODE -eq 0) {
					Write-Output "  ✅ Python aggiornato"
				}
				else {
					Write-Warning "  ⚠ Python non aggiornato (potrebbe essere già alla versione più recente)"
				}
			}
			catch {
				Write-Warning "  ⚠ Errore durante l'aggiornamento Python: $_"
			}
		}
		
		# Aggiorna tutti i pacchetti conda nell'ambiente
		Write-Output "  → Aggiornamento pacchetti conda..."
		try {
			& $script:anacondaPython -m conda update -n $EnvName --all -y 2>$null
			if ($LASTEXITCODE -eq 0) {
				Write-Output "  ✅ Pacchetti conda aggiornati"
			}
			else {
				Write-Warning "  ⚠ Alcuni pacchetti conda potrebbero non essere stati aggiornati"
			}
		}
		catch {
			Write-Warning "  ⚠ Errore durante l'aggiornamento pacchetti conda: $_"
		}
        
		# Aggiorna pip nell'ambiente specifico usando il percorso diretto
		Write-Output "  → Aggiornamento pip..."
		try {
			if (Test-Path $envPython) {
				& $envPython -m pip install --upgrade pip 2>$null
				if ($LASTEXITCODE -eq 0) {
					Write-Output "  ✅ Pip aggiornato"
				}
				else {
					Write-Warning "  ⚠ Pip non aggiornato"
				}
			}
			else {
				Write-Warning "  ⚠ Python non trovato nell'ambiente $EnvName"
			}
		}
		catch {
			Write-Warning "  ⚠ Errore durante l'aggiornamento pip: $_"
		}
        
		# Aggiorna tutti i pacchetti pip nell'ambiente
		Write-Output "  → Aggiornamento pacchetti pip..."
		try {
			if (Test-Path $envPython) {
				# Lista pacchetti obsoleti e aggiornali
				$outdated = & $envPython -m pip list --outdated --format=json 2>$null | ConvertFrom-Json
				if ($outdated -and $outdated.Count -gt 0) {
					foreach ($package in $outdated) {
						& $envPython -m pip install --upgrade $package.name 2>$null
					}
					Write-Output "  ✅ Pacchetti pip aggiornati ($($outdated.Count) pacchetti)"
				}
				else {
					Write-Output "  ✅ Tutti i pacchetti pip sono già aggiornati"
				}
			}
		}
		catch {
			Write-Warning "  ⚠ Errore durante l'aggiornamento pacchetti pip: $_"
		}
        
		# Pulizia cache conda
		Write-Output "  → Pulizia cache..."
		try {
			& $anacondaPython -m conda clean -n $EnvName --all -y 2>$null
			Write-Output "  ✅ Cache pulita"
		}
		catch {
			Write-Warning "  ⚠ Errore durante la pulizia cache: $_"
		}
        
		Write-Output "  ✅ Ambiente '$EnvName' aggiornato con successo"
		Write-Output ""
        
	}
	catch {
		Write-Error "❌ Errore durante l'aggiornamento dell'ambiente '$EnvName': $_"
		Write-Output ""
	}
}

# Ottieni la lista di tutti gli ambienti conda (escludendo l'ambiente base)
Write-Output "🔍 Ricerca ambienti conda disponibili..."
$envList = & $anacondaPython -m conda env list 2>$null

if (-not $envList) {
	Write-Error "Impossibile ottenere la lista degli ambienti conda."
	exit
}

# Estrai i nomi degli ambienti (escludendo base e righe di commento)
$environments = @()
foreach ($line in $envList) {
	if ($line -match '^\s*([^\s#]+)\s+' -and $Matches[1] -ne "base" -and $line -notmatch '^#') {
		$envName = $Matches[1].Trim()
		if ($envName -and $envName -ne "base") {
			$environments += $envName
		}
	}
}

if ($environments.Count -eq 0) {
	Write-Output "ℹ Nessun ambiente conda da aggiornare (oltre a base)."
	exit
}

Write-Output "📋 Trovati $($environments.Count) ambienti da aggiornare:"
foreach ($env in $environments) {
	Write-Output "  • $env"
}
Write-Output ""

# Chiedi conferma all'utente
$confirmation = Read-Host "Vuoi procedere con l'aggiornamento di tutti gli ambienti? (s/N)"
if ($confirmation -notmatch '^[sS]') {
	Write-Output "Aggiornamento annullato dall'utente."
	exit
}

Write-Output ""
Write-Output "🚀 Avvio aggiornamento ambienti..."
Write-Output ""

$successCount = 0
$errorCount = 0

# Aggiorna ogni ambiente
foreach ($envName in $environments) {
	try {
		Update-CondaEnvironment -EnvName $envName -PythonUpdateMode $pythonUpdateMode
		$successCount++
	}
	catch {
		Write-Error "❌ Fallito aggiornamento di '$envName'"
		$errorCount++
	}
}

# Aggiorna anche l'ambiente base
Write-Output "📦 Aggiornamento ambiente base..."
try {
	& $anacondaPython -m conda update -n base --all -y
	if ($LASTEXITCODE -eq 0) {
		Write-Output "✅ Ambiente base aggiornato con successo"
		$successCount++
	}
 else {
		Write-Warning "⚠ Alcuni pacchetti nell'ambiente base potrebbero non essere stati aggiornati"
		$errorCount++
	}
}
catch {
	Write-Error "❌ Errore durante l'aggiornamento dell'ambiente base: $_"
	$errorCount++
}

# Ripristina l'ambiente base
Write-Output ""
Write-Output "🔄 Ripristino ambiente base..."
try {
	& $anacondaPython -m conda activate base
	Write-Output "✅ Ambiente base ripristinato correttamente"
}
catch {
	Write-Warning "⚠ Non è stato possibile ripristinare l'ambiente base: $_"
}

# Pulizia finale globale
Write-Output ""
Write-Output "🧹 Pulizia finale..."
try {
	& $anacondaPython -m conda clean --all -y 2>$null
	Write-Output "✅ Pulizia completata"
}
catch {
	Write-Warning "⚠ Pulizia parzialmente completata"
}

# Riepilogo finale
Write-Output ""
Write-Output "=== RIEPILOGO AGGIORNAMENTO ==="
Write-Output "✅ Ambienti aggiornati con successo: $successCount"
if ($errorCount -gt 0) {
	Write-Output "❌ Ambienti con errori: $errorCount"
}
Write-Output "📅 Completato: $(Get-Date)"

# Ripristina l'ambiente base di conda
Write-Output ""
Write-Output "🔄 Ripristino ambiente base di conda..."
try {
	& $anacondaPython -m conda activate base 2>$null
	Write-Output "✅ Ambiente base ripristinato correttamente."
}
catch {
	Write-Warning "⚠ Non è stato possibile ripristinare l'ambiente base: $_"
	Write-Output "💡 Per ripristinare manualmente: conda activate base"
}

Write-Output ""
Write-Output "💡 Suggerimento: Riavvia il terminale per assicurarti che tutti i cambiamenti siano attivi."