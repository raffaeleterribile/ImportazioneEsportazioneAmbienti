# Script di Importazione/Aggiornamento Ambienti Conda - Riepilogo Funzionalità

## PROBLEMA RISOLTO:
Gli script di importazione conda si bloccavano durante l'aggiornamento degli ambienti, 
specialmente per movidius, udacity e vllm che si fermano durante la risoluzione delle dipendenze.

## SOLUZIONI IMPLEMENTATE:

### 1. GESTIONE TIMEOUT
- Timeout configurabile (default: 600 secondi / 10 minuti)
- Gestione automatica per ambienti problematici identificati
- Jobs PowerShell per esecuzione con timeout

### 2. PARAMETRI E CONFIGURAZIONE
```powershell
.\import_conda_envs.ps1 -ImportDir "conda_env_exports" -TimeoutSeconds 600
```

### 3. ANALISI AUTOMATICA DELLA COMPLESSITÀ
**Criteri per rilevamento ambienti complessi:**
- Molte dipendenze (>20 pacchetti)
- Canali non standard o multipli canali complessi
- Versioni Python specifiche/legacy (es. python=3.6.8)
- Pacchetti problematici (tensorflow, pytorch, opencv, gdal, etc.)
- Dipendenze pip (spesso causano conflitti)  
- File YAML molto grandi (>2KB indica complessità)

**Vantaggi dell'analisi automatica:**
- Nessuna lista hard-coded di ambienti
- Adattamento automatico a nuovi ambienti
- Analisi basata sul contenuto effettivo
- Gestione intelligente della complessità

### 4. GESTIONE DIFFERENZIATA
**Ambienti STANDARD:**
- Procedura conda normale
- Nessun timeout speciale
- Processamento veloce

**Ambienti COMPLESSI (rilevati automaticamente):**
- Solver libmamba (più veloce e robusto)
- Timeout automatico configurabile
- Gestione errori dedicata
- Monitoraggio con PowerShell Jobs

### 5. RIEPILOGO DETTAGLIATO
Al termine dell'esecuzione fornisce:
- Totale ambienti processati  
- Successi e fallimenti
- **Analisi della complessità** con classificazione automatica
- Lista ambienti standard vs complessi
- Ambienti con timeout e suggerimenti di risoluzione

### 6. RILEVAMENTO AUTOMATICO
- **Rilevamento dinamico di Anaconda/Miniconda**:
  - Anaconda: C:\ProgramData\Anaconda, C:\Anaconda3, %USERPROFILE%\Anaconda3, ecc.
  - Miniconda: C:\ProgramData\Miniconda3, C:\Miniconda3, %USERPROFILE%\Miniconda3, ecc.
  - Variabili d'ambiente: CONDA_PREFIX, CONDA_EXE
  - PATH system: ricerca automatica di conda.exe
- **Portabilità completa**: funziona su qualsiasi installazione standard

### 7. COMPATIBILITÀ
- Funziona con conda 24.11.3+
- Usa python -m conda per evitare bug conda-script.py
- **Rilevamento dinamico** in TUTTI gli script (import + update)
- Percorsi dinamici per massima portabilità
- Gestione errori robusta

### 8. SCRIPTS DISPONIBILI
**`import_conda_envs.ps1`**:
- Importa/aggiorna ambienti da file YAML
- Analisi automatica della complessità  
- Gestione timeout per ambienti complessi
- Rilevamento dinamico Anaconda/Miniconda

**`update_conda_envs.ps1`**:
- Aggiorna tutti gli ambienti esistenti
- Opzioni configurabili per Python (-yes/-no/-ask)
- Aggiornamento ambiente base incluso
- Rilevamento dinamico Anaconda/Miniconda

## ESEMPIO UTILIZZO:

```powershell
# Importazione standard
.\import_conda_envs.ps1

# Con timeout personalizzato (5 minuti)
.\import_conda_envs.ps1 -TimeoutSeconds 300

# Directory personalizzata
.\import_conda_envs.ps1 -ImportDir "my_environments"
```

## OUTPUT ESEMPIO:
```
=== Importazione Ambienti Conda ===
Directory di importazione: conda_env_exports
Timeout per ambienti problematici: 600s
Ambienti problematici identificati: movidius, udacity, vllm

Processando: audio
L'ambiente 'audio' esiste già. Aggiornamento in corso...
Aggiornato l'ambiente audio da audio.yml

Processando: movidius  
L'ambiente 'movidius' esiste già. Aggiornamento in corso...
WARNING: L'ambiente 'movidius' è nella lista degli ambienti problematici. Uso timeout e parametri speciali.
Esecuzione comando (timeout: 600s): conda env update -n movidius -f conda_env_exports\movidius.yml --solver=libmamba
WARNING: Timeout raggiunto (600s) per l'ambiente movidius

=== RIEPILOGO IMPORTAZIONE ===
Totale ambienti processati: 25
Ambienti completati con successo: 22
Ambienti falliti: 0
Ambienti timeout: 3

Ambienti con timeout (potrebbero essere problematici):
  - movidius
  - udacity
  - vllm

SUGGERIMENTO: Prova ad aumentare il timeout con -TimeoutSeconds per questi ambienti
oppure aggiornali manualmente con:
  conda env update -n movidius -f conda_env_exports\movidius.yml
  conda env update -n udacity -f conda_env_exports\udacity.yml  
  conda env update -n vllm -f conda_env_exports\vllm.yml

Importazione completata!
```