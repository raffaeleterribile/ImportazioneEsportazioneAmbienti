# Script di Gestione Ambienti Conda

Collezione di script PowerShell per l'esportazione, importazione e aggiornamento di ambienti Conda con gestione avanzata degli errori e supporto per ambienti complessi.

## DESCRIZIONE DEGLI SCRIPT

### 📤 `export_conda_envs.ps1`
Esporta tutti gli ambienti Conda presenti nel sistema in file YAML individuali.

**Funzionalità:**
- Rilevamento automatico di tutti gli ambienti conda esistenti
- Esportazione in formato YAML con dipendenze complete
- Creazione automatica della directory `conda_env_exports`
- Gestione errori per ambienti corrotti o inaccessibili
- Report finale con statistiche di esportazione

### 📥 `import_conda_envs.ps1`
Importa o aggiorna ambienti Conda da file YAML con gestione avanzata per ambienti problematici.

**Funzionalità principali:**
- Importazione/aggiornamento da file YAML
- Modalità upgrade pacchetti con rimozione pin di versione
- Analisi automatica della complessità degli ambienti
- Gestione timeout per ambienti problematici
- Rilevamento e diagnosi errori pip/conda specifici
- Report dettagliato con suggerimenti di risoluzione

### 🔄 `update_conda_envs.ps1`
Aggiorna tutti gli ambienti Conda esistenti nel sistema.

**Funzionalità:**
- Aggiornamento massivo di tutti gli ambienti
- Opzioni configurabili per aggiornamento Python
- Aggiornamento ambiente base incluso
- Gestione errori per ambienti non aggiornabili
- Statistiche dettagliate dell'operazione

## PROBLEMI RISOLTI:
1. **Blocchi durante la risoluzione delle dipendenze** - specialmente per ambienti complessi
2. **Errori pip non rilevati** - conflitti di dipendenze non segnalati correttamente
3. **Versioni obsolete** - impossibilità di usare versioni più recenti dei pacchetti

## SOLUZIONI IMPLEMENTATE:

### 1. GESTIONE TIMEOUT
- Timeout configurabile (default: 600 secondi / 10 minuti)
- Gestione automatica per ambienti problematici identificati
- Jobs PowerShell per esecuzione con timeout

### 2. NUOVA FUNZIONALITÀ: MODALITÀ UPGRADE PACCHETTI
```powershell
.\import_conda_envs.ps1 -UpgradePackages
```
**Cosa fa:**
- Crea file YAML temporanei senza pin di versione
- Rimuove automaticamente tutti i `=versione` dai pacchetti
- Installa le versioni più recenti compatibili invece di quelle esatte
- Risolve automaticamente conflitti di dipendenze obsolete

### 3. PARAMETRI E CONFIGURAZIONE
```powershell
# Importazione standard (versioni esatte dal YAML)
.\import_conda_envs.ps1 -ImportDir "conda_env_exports" -TimeoutSeconds 600

# Modalità upgrade (versioni più recenti)
.\import_conda_envs.ps1 -UpgradePackages -TimeoutSeconds 600
```

### 4. GESTIONE ERRORI MIGLIORATA
**Rilevamento specifico di errori:**
- **Errori pip**: Conflitti dipendenze pip (ResolutionImpossible, Pip subprocess error)
- **Errori conda**: Conflitti pacchetti conda
- **Timeout**: Superamento tempo limite
- **Exit codes**: Rilevamento automatico di comandi falliti

**Suggerimenti mirati:**
- Errori pip → Prova modalità `-UpgradePackages`
- Conflitti versioni → Usa `--force-reinstall`
- Pacchetti non trovati → Rimuovi versioni specifiche dal YAML

### 5. ANALISI AUTOMATICA DELLA COMPLESSITÀ
**Criteri per rilevamento ambienti complessi:**
- Molte dipendenze (>20 pacchetti)
- Canali non standard o multipli canali complessi
- Versioni Python specifiche/legacy (es. python=3.6.8)
- Pacchetti problematici (machine learning, computer vision, geospatial, etc.)
- Dipendenze pip (spesso causano conflitti), specialmente >5 dipendenze pip
- File YAML molto grandi (>2KB indica complessità)

**Vantaggi dell'analisi automatica:**
- Nessuna lista hard-coded di ambienti
- Adattamento automatico a nuovi ambienti
- Analisi basata sul contenuto effettivo
- Gestione intelligente della complessità

### 6. GESTIONE DIFFERENZIATA
**Ambienti STANDARD:**
- Procedura conda normale
- Nessun timeout speciale
- Processamento veloce

**Ambienti COMPLESSI (rilevati automaticamente):**
- Solver libmamba (più veloce e robusto)
- Timeout automatico configurabile
- Gestione errori dedicata
- Monitoraggio con PowerShell Jobs

### 7. RIEPILOGO DETTAGLIATO AVANZATO
Al termine dell'esecuzione fornisce:
- **Statistiche complete**: Totale processati, successi, fallimenti, timeout, tasso di successo
- **Analisi per complessità**: Classificazione automatica standard vs complessi
- **Operazioni dettagliate**: Distingue tra creati/aggiornati con tipo di ambiente
- **Diagnosi errori specifica**: Identifica errori pip, conda, timeout con suggerimenti mirati
- **Strategie di risoluzione**: Comandi specifici per risolvere problemi comuni
- **Rapporto su file**: Salvataggio automatico del report dettagliato

### 8. RILEVAMENTO AUTOMATICO
- **Rilevamento dinamico di Anaconda/Miniconda**:
  - Anaconda: C:\ProgramData\Anaconda, C:\Anaconda3, %USERPROFILE%\Anaconda3, ecc.
  - Miniconda: C:\ProgramData\Miniconda3, C:\Miniconda3, %USERPROFILE%\Miniconda3, ecc.
  - Variabili d'ambiente: CONDA_PREFIX, CONDA_EXE
  - PATH system: ricerca automatica di conda.exe
- **Portabilità completa**: funziona su qualsiasi installazione standard

### 9. COMPATIBILITÀ
- Funziona con conda 24.11.3+
- Usa python -m conda per evitare bug conda-script.py
- **Rilevamento dinamico** in TUTTI gli script (import + update)
- Percorsi dinamici per massima portabilità
- Gestione errori robusta

### 10. PARAMETRI E SINTASSI

**`export_conda_envs.ps1`**:
```powershell
.\export_conda_envs.ps1 [-ExportDir "directory_esportazione"]
```
- **ExportDir**: Directory di destinazione per i file YAML (default: "conda_env_exports")

**`import_conda_envs.ps1`**:
```powershell
.\import_conda_envs.ps1 [-ImportDir "directory"] [-TimeoutSeconds 600] [-UpgradePackages]
```
- **ImportDir**: Directory contenente i file YAML (default: "conda_env_exports")
- **TimeoutSeconds**: Timeout per ambienti complessi (default: 600 secondi)
- **UpgradePackages**: Usa versioni più recenti invece di quelle esatte dal YAML

**`update_conda_envs.ps1`**:
```powershell
.\update_conda_envs.ps1 [-UpdatePython {yes|no|ask}]
```
- **UpdatePython**: Controlla se aggiornare anche Python negli ambienti

## WORKFLOW TIPICO DI UTILIZZO

### 🔄 Scenario 1: Backup e Ripristino Completo
```powershell
# 1. Esporta tutti gli ambienti attuali
.\export_conda_envs.ps1

# 2. (Dopo reinstallazione/migrazione) Importa tutti gli ambienti
.\import_conda_envs.ps1

# 3. (Opzionale) Se hai errori di dipendenze, usa modalità upgrade
.\import_conda_envs.ps1 -UpgradePackages
```

### 🆕 Scenario 2: Condivisione Ambienti tra Sistemi
```powershell
# Sistema A: Esporta ambienti
.\export_conda_envs.ps1 -ExportDir "shared_envs"

# Sistema B: Importa con versioni aggiornate
.\import_conda_envs.ps1 -ImportDir "shared_envs" -UpgradePackages
```

### 🔧 Scenario 3: Manutenzione Periodica
```powershell
# Aggiorna tutti gli ambienti esistenti
.\update_conda_envs.ps1

# Poi esporta le nuove configurazioni
.\export_conda_envs.ps1
```

## MODALITÀ UPGRADE PACCHETTI - DETTAGLI:

### Quando usare `-UpgradePackages`:
✅ **Quando hai errori di dipendenze pip** (ResolutionImpossible, conflitti protobuf, etc.)  
✅ **File YAML obsoleti** (esportati mesi fa con versioni vecchie)  
✅ **Vuoi le ultime versioni** invece di quelle del momento dell'export  
✅ **Conflitti di versioni** tra pacchetti correlati  

### Come funziona:
1. **File originale** (ml_env.yml):
```yaml
dependencies:
  - python=3.8.5
  - numpy=1.21.0
  - pip:
    - tensorflow==2.8.0
```

2. **File temporaneo generato** (ml_env_unpinned.yml):
```yaml
dependencies:
  - python
  - numpy
  - pip:
    - tensorflow
```

3. **Risultato**: Installa le versioni più recenti compatibili

### Confronto modalità:
| Modalità | Versioni | Pro | Contro |
|----------|----------|-----|--------|
| **Standard** | Esatte dal YAML | Riproducibilità garantita | Possibili conflitti con versioni obsolete |
| **Upgrade** | Più recenti compatibili | Risolve conflitti automaticamente | Meno riproducibile |

## ESEMPIO UTILIZZO:

```powershell
# Importazione standard (versioni esatte dal YAML)
.\import_conda_envs.ps1

# NUOVA: Modalità upgrade (versioni più recenti)
.\import_conda_envs.ps1 -UpgradePackages

# Con timeout personalizzato (5 minuti)
.\import_conda_envs.ps1 -TimeoutSeconds 300

# Combinazione modalità upgrade + timeout personalizzato
.\import_conda_envs.ps1 -UpgradePackages -TimeoutSeconds 1200

# Directory personalizzata
.\import_conda_envs.ps1 -ImportDir "my_environments" -UpgradePackages

# Esportazione in directory personalizzata
.\export_conda_envs.ps1 -ExportDir "backup_envs"
```

## OUTPUT ESEMPIO (MIGLIORATO):
```
=== Importazione Ambienti Conda ===
Directory di importazione: conda_env_exports
Timeout per ambienti complessi: 600s
Modalità upgrade pacchetti: ATTIVATA (usa versioni più recenti)
Analisi automatica della complessità degli ambienti attivata
🔧 Directory temporanea per YAML senza pin: C:\Users\...\Temp\conda_unpinned_20251112143022

🔧 Preparazione file YAML senza pin di versione per 'data_science'...
   📝 File YAML senza pin creato: data_science_unpinned.yml
Ambiente 'data_science': COMPLESSO - Versione Python specifica/legacy
Creazione nuovo ambiente data_science da data_science_unpinned.yml
Usando gestione speciale per ambiente complesso 'data_science'
Errore durante la creazione dell'ambiente complesso 'data_science': Errore pip durante installazione: Pip subprocess error; ERROR: Cannot install tensorflow==2.8.0

════════════════════════════════════════════════════════════════
                    RIEPILOGO DETTAGLIATO IMPORTAZIONE
════════════════════════════════════════════════════════════════

📊 STATISTICHE GENERALI:
   • Totale ambienti processati: 25
   • ✅ Completati con successo: 22
   • ❌ Falliti: 2
   • ⏰ Timeout: 1
   • 📈 Tasso di successo: 88.0%

🔧 ANALISI PER COMPLESSITÀ:
   • 📝 Ambienti standard: 15
   • 🔬 Ambienti complessi: 10

⚡ OPERAZIONI ESEGUITE:
   • 🆕 Nuovi ambienti creati: 8
   • 🔄 Ambienti aggiornati: 14

❌ AMBIENTI FALLITI - DIAGNOSI ERRORI:
   ❌ data_science (Operazione: Create, Tipo: Complex)
      💡 Errore: Errore pip durante installazione: Pip subprocess error; ERROR: Cannot install tensorflow==2.8.0
      🔧 Suggerimento: Conflitto nelle dipendenze pip
         • Le dipendenze pip nel file YAML sono incompatibili
         • Prova: .\import_conda_envs.ps1 -UpgradePackages (usa versioni più recenti)
         • Oppure modifica manualmente il file YAML rimuovendo le dipendenze pip problematiche

💡 RACCOMANDAZIONI GENERALI:
🔧 PER RISOLVERE PROBLEMI COMUNI:
   • Aggiorna conda: conda update conda
   • Pulisci cache: conda clean --all
   • Verifica spazio disco: almeno 2GB liberi per ambiente
   • Controlla connessione ai repository conda

🧹 File YAML temporanei puliti
📄 Rapporto dettagliato salvato in: import_report_20251112_143045.txt

════════════════════════════════════════════════════════════════
                       IMPORTAZIONE COMPLETATA!
════════════════════════════════════════════════════════════════
```