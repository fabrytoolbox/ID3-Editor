# Joe-Colton-ID3-Editor.ps1 - v1.0 (Matrix Edition)
# Codename: "Joe Colton" (G.I. Joe: Retaliation)
# Editor di metadati ID3 per file MP3 con GUI Matrix.
# Richiede PowerShell 7.2+ e il modulo TagLibCli.

#Requires -Version 7.2

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# CONFIGURAZIONE E PERCORSI
# ============================================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:logFile = $null
$script:tagsFilePath = Join-Path $scriptPath "tags.xml"
$script:tagsData = $null

# ============================================================
# LOGGING
# ============================================================
function Start-Log {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $scriptPath "joe_colton_id3_$timestamp.log"
    @(
        "============================================================",
        " JOE COLTON ID3 EDITOR v1.0 - LOG",
        "============================================================",
        "Data inizio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "PowerShell : $($PSVersionTable.PSVersion)",
        "============================================================",
        ""
    ) | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $script:logFile) { return }
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8
}

Start-Log

# ============================================================
# CONTROLLO TAGLIBCLI
# ============================================================
function Test-TagLib {
    $module = Get-Module -ListAvailable -Name TagLibCli
    if (-not $module) {
        Write-Host "[INFO] Modulo TagLibCli non trovato. Installazione in corso..." -ForegroundColor Yellow
        try {
            Install-Module -Name TagLibCli -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "[OK] TagLibCli installato." -ForegroundColor Green
        } catch {
            Write-Host "[ERRORE] Impossibile installare TagLibCli: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Prova a lanciare: Install-Module -Name TagLibCli -Scope CurrentUser" -ForegroundColor Yellow
            exit 1
        }
    }
    Import-Module TagLibCli -ErrorAction Stop
}

Test-TagLib

# ============================================================
# GESTIONE FILE TAGS.XML
# ============================================================
function Load-TagsXml {
    if (Test-Path $script:tagsFilePath) {
        try {
            $raw = Get-Content -Path $script:tagsFilePath -Raw -Encoding UTF8
            $clean = $raw.TrimStart([char]0xFEFF, [char]0x200B, [char]0x0000, " ", "`r", "`n")
            $script:tagsData = [xml]$clean
            Write-Log "File tags.xml caricato: $($script:tagsFilePath)" "OK"
        } catch {
            Write-Log "Errore nel parsing di tags.xml: $($_.Exception.Message)" "ERROR"
            return $false
        }
    } else {
        # Crea un file tags.xml di default
        Write-Log "File tags.xml non trovato. Creazione di un file di default." "WARN"
        $defaultXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Tags>
    <ArtistiSingoli>
        <Artista>Fabio Concato</Artista>
        <Artista>Papik</Artista>
        <Artista>Aretha Franklin</Artista>
        <Artista>George Benson</Artista>
    </ArtistiSingoli>
    <Generi>
        <Genere>Pop</Genere>
        <Genere>Jazz</Genere>
        <Genere>Nu-Jazz</Genere>
        <Genere>Soul</Genere>
        <Genere>R&amp;B</Genere>
    </Generi>
    <Duetti>
        <Duetto>Fabio Concato feat. Papik</Duetto>
        <Duetto>George Benson &amp; Aretha Franklin</Duetto>
    </Duetti>
</Tags>
"@
        try {
            $defaultXml | Set-Content -Path $script:tagsFilePath -Encoding UTF8
            $script:tagsData = [xml]$defaultXml
            Write-Log "Creato tags.xml con dati di default." "OK"
        } catch {
            Write-Log "Impossibile creare tags.xml: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    return $true
}

if (-not (Load-TagsXml)) {
    [System.Windows.Forms.MessageBox]::Show("Impossibile caricare o creare il file tags.xml.`nControlla i permessi della cartella.", "MATRIX - ERRORE", "OK", "Error") | Out-Null
    exit
}

# ============================================================
# GUI
# ============================================================
# (Verrà costruita nel Blocco 3/4)

# ---------------------------------------------
# Fine primo blocco 
# ---------------------------------------------

# ============================================================
# FUNZIONI PER I TAG E L'AUTO-APPRENDIMENTO
# ============================================================

# Funzione di "Sanità Mentale" per i tag
function Format-TagValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    
    # 1. Rimuove spazi iniziali e finali
    $clean = $Value.Trim()
    
    # 2. Ignora valori "spazzatura"
    $junkValues = @("N/A", "Unknown", "Sconosciuto", "Unknow", "Null", "-")
    if ($clean -in $junkValues) { return "" }
    
    # 3. (Opzionale) Capitalizza la prima lettera se tutto minuscolo
    # (Lo commento per ora, perché a volte gli artisti hanno nomi strani, es. "deadmau5")
    # if ($clean -cmatch '^[a-z]') { $clean = $clean.Substring(0,1).ToUpper() + $clean.Substring(1) }
    
    return $clean
}

# Controlla se un valore esiste già nell'XML (case-insensitive)
function Test-TagInXml {
    param([string]$Value, [string]$Category)
    
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    
    $searchValue = $Value.Trim()
    
    if ($Category -eq "Artista") {
        $existing = $script:tagsData.Tags.ArtistiSingoli.Artista
    } elseif ($Category -eq "Genere") {
        $existing = $script:tagsData.Tags.Generi.Genere
    } elseif ($Category -eq "Duetto") {
        $existing = $script:tagsData.Tags.Duetti.Duetto
    } else {
        return $false
    }

    # Controllo case-insensitive
    foreach ($item in $existing) {
        if ($item -eq $searchValue) { return $true }
    }
    return $false
}

# Aggiunge un nuovo valore all'XML (se non esiste)
function Add-TagToXml {
    param([string]$Value, [string]$Category)
    
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    if (Test-TagInXml -Value $Value -Category $Category) { return } # Esiste già, non fare nulla

    $newNode = $script:tagsData.CreateElement("Artista") # Default per Artista
    if ($Category -eq "Genere") { $newNode = $script:tagsData.CreateElement("Genere") }
    elseif ($Category -eq "Duetto") { $newNode = $script:tagsData.CreateElement("Duetto") }

    $newNode.InnerText = $Value.Trim()
    
    if ($Category -eq "Artista") {
        $script:tagsData.Tags.ArtistiSingoli.AppendChild($newNode) | Out-Null
    } elseif ($Category -eq "Genere") {
        $script:tagsData.Tags.Generi.AppendChild($newNode) | Out-Null
    } elseif ($Category -eq "Duetto") {
        $script:tagsData.Tags.Duetti.AppendChild($newNode) | Out-Null
    }
    
    Write-Log "Nuovo $Category aggiunto all'XML: $Value" "OK"
}

# Salva l'XML aggiornato su disco
function Save-TagsXml {
    try {
        $script:tagsData.Save($script:tagsFilePath)
        Write-Log "File tags.xml aggiornato su disco." "OK"
    } catch {
        Write-Log "Errore nel salvataggio di tags.xml: $($_.Exception.Message)" "ERROR"
    }
}

# Legge i tag da un file MP3
function Get-Mp3Tags {
    param([string]$FilePath)
    
    try {
        $tagFile = [TagLib.File]::Create($FilePath)
        
        $tags = @{
            Titolo = Format-TagValue $tagFile.Tag.Title
            Artista = Format-TagValue $tagFile.Tag.FirstPerformer
            Album = Format-TagValue $tagFile.Tag.Album
            Genere = Format-TagValue $tagFile.Tag.FirstGenre
            Anno = if ($tagFile.Tag.Year -gt 0) { $tagFile.Tag.Year } else { "" }
            Traccia = if ($tagFile.Tag.Track -gt 0) { $tagFile.Tag.Track } else { "" }
        }
        
        $tagFile.Dispose()
        return $tags
    } catch {
        Write-Log "Impossibile leggere i tag di $FilePath : $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Scrive i tag in un file MP3
function Set-Mp3Tags {
    param(
        [string]$FilePath,
        [string]$Titolo,
        [string]$Artista,
        [string]$Album,
        [string]$Genere,
        [int]$Anno,
        [int]$Traccia
    )
    
    try {
        $tagFile = [TagLib.File]::Create($FilePath)
        
        $tagFile.Tag.Title = $Titolo
        $tagFile.Tag.Performers = @($Artista) # Sovrascrive con un array a un elemento
        $tagFile.Tag.Album = $Album
        $tagFile.Tag.Genres = @($Genere)
        if ($Anno -gt 0) { $tagFile.Tag.Year = $Anno }
        if ($Traccia -gt 0) { $tagFile.Tag.Track = $Traccia }
        
        $tagFile.Save()
        $tagFile.Dispose()
        
        Write-Log "Tag salvati per: $FilePath" "OK"
        return $true
    } catch {
        Write-Log "Errore nel salvataggio dei tag per $FilePath : $($_.Exception.Message)" "ERROR"
        return $false
    }
}
# ----------------------------------------------------
# 				Fine secondo blocco
# ----------------------------------------------------
# ============================================================
# INTERFACCIA GRAFICA - MATRIX EDITION
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "JOE COLTON ID3 EDITOR v1.0"
$form.Size            = New-Object System.Drawing.Size(850, 700)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::Black
$form.ForeColor       = [System.Drawing.Color]::Lime
$form.Font            = New-Object System.Drawing.Font("Consolas", 10)

# --- HEADER ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "JOE COLTON ID3 EDITOR v1.0"
$lblTitle.ForeColor = [System.Drawing.Color]::Lime
$lblTitle.Font      = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location  = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size      = New-Object System.Drawing.Size(800, 30)
$form.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text      = ":: EDITOR METADATI MP3 : MATRIX EDITION ::"
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 180, 0)
$lblSubtitle.Font      = New-Object System.Drawing.Font("Consolas", 9)
$lblSubtitle.Location  = New-Object System.Drawing.Point(20, 50)
$lblSubtitle.Size      = New-Object System.Drawing.Size(800, 18)
$form.Controls.Add($lblSubtitle)

# --- SELEZIONE FILE ---
$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Text = "File MP3:"; $lblFile.Location = New-Object System.Drawing.Point(20, 85)
$lblFile.Size = New-Object System.Drawing.Size(100, 20); $form.Controls.Add($lblFile)

$global:txtFile = New-Object System.Windows.Forms.TextBox
$global:txtFile.Location = New-Object System.Drawing.Point(130, 82); $global:txtFile.Size = New-Object System.Drawing.Size(580, 26)
$global:txtFile.BackColor = [System.Drawing.Color]::Black; $global:txtFile.ForeColor = [System.Drawing.Color]::Lime
$global:txtFile.BorderStyle = "FixedSingle"
$form.Controls.Add($global:txtFile)

$global:btnBrowse = New-Object System.Windows.Forms.Button
$global:btnBrowse.Text = "SFOGLIA"; $global:btnBrowse.Location = New-Object System.Drawing.Point(720, 80)
$global:btnBrowse.Size = New-Object System.Drawing.Size(100, 30); $global:btnBrowse.FlatStyle = "Flat"
$global:btnBrowse.ForeColor = [System.Drawing.Color]::Lime; $global:btnBrowse.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
$form.Controls.Add($global:btnBrowse)

# --- GRUPPO METADATI ---
$gbTags = New-Object System.Windows.Forms.GroupBox
$gbTags.Text = "[ METADATI ]"; $gbTags.ForeColor = [System.Drawing.Color]::Lime
$gbTags.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$gbTags.Location = New-Object System.Drawing.Point(20, 125); $gbTags.Size = New-Object System.Drawing.Size(800, 200)
$form.Controls.Add($gbTags)

# Riga 1: Titolo (TextBox)
$lblTitolo = New-Object System.Windows.Forms.Label; $lblTitolo.Text = "Titolo:"; $lblTitolo.Location = New-Object System.Drawing.Point(20, 30); $lblTitolo.Size = New-Object System.Drawing.Size(80, 20); $gbTags.Controls.Add($lblTitolo)
$global:txtTitolo = New-Object System.Windows.Forms.TextBox; $global:txtTitolo.Location = New-Object System.Drawing.Point(110, 28); $global:txtTitolo.Size = New-Object System.Drawing.Size(660, 26)
$global:txtTitolo.BackColor = [System.Drawing.Color]::Black; $global:txtTitolo.ForeColor = [System.Drawing.Color]::Lime; $gbTags.Controls.Add($global:txtTitolo)

# Riga 2: Artista (ComboBox)
$lblArtista = New-Object System.Windows.Forms.Label; $lblArtista.Text = "Artista:"; $lblArtista.Location = New-Object System.Drawing.Point(20, 70); $lblArtista.Size = New-Object System.Drawing.Size(80, 20); $gbTags.Controls.Add($lblArtista)
$global:cmbArtista = New-Object System.Windows.Forms.ComboBox; $global:cmbArtista.Location = New-Object System.Drawing.Point(110, 68); $global:cmbArtista.Size = New-Object System.Drawing.Size(300, 26)
$global:cmbArtista.BackColor = [System.Drawing.Color]::Black; $global:cmbArtista.ForeColor = [System.Drawing.Color]::Lime; $global:cmbArtista.DropDownStyle = "DropDown"
$gbTags.Controls.Add($global:cmbArtista)

# Riga 2b: Duetto/Featuring (ComboBox)
$lblDuetto = New-Object System.Windows.Forms.Label; $lblDuetto.Text = "Duetto/Feat:"; $lblDuetto.Location = New-Object System.Drawing.Point(420, 70); $lblDuetto.Size = New-Object System.Drawing.Size(100, 20); $gbTags.Controls.Add($lblDuetto)
$global:cmbDuetto = New-Object System.Windows.Forms.ComboBox; $global:cmbDuetto.Location = New-Object System.Drawing.Point(530, 68); $global:cmbDuetto.Size = New-Object System.Drawing.Size(240, 26)
$global:cmbDuetto.BackColor = [System.Drawing.Color]::Black; $global:cmbDuetto.ForeColor = [System.Drawing.Color]::Lime; $global:cmbDuetto.DropDownStyle = "DropDown"
$gbTags.Controls.Add($global:cmbDuetto)

# Riga 3: Album (TextBox)
$lblAlbum = New-Object System.Windows.Forms.Label; $lblAlbum.Text = "Album:"; $lblAlbum.Location = New-Object System.Drawing.Point(20, 110); $lblAlbum.Size = New-Object System.Drawing.Size(80, 20); $gbTags.Controls.Add($lblAlbum)
$global:txtAlbum = New-Object System.Windows.Forms.TextBox; $global:txtAlbum.Location = New-Object System.Drawing.Point(110, 108); $global:txtAlbum.Size = New-Object System.Drawing.Size(300, 26)
$global:txtAlbum.BackColor = [System.Drawing.Color]::Black; $global:txtAlbum.ForeColor = [System.Drawing.Color]::Lime; $gbTags.Controls.Add($global:txtAlbum)

# Riga 3b: Genere (ComboBox)
$lblGenere = New-Object System.Windows.Forms.Label; $lblGenere.Text = "Genere:"; $lblGenere.Location = New-Object System.Drawing.Point(420, 110); $lblGenere.Size = New-Object System.Drawing.Size(80, 20); $gbTags.Controls.Add($lblGenere)
$global:cmbGenere = New-Object System.Windows.Forms.ComboBox; $global:cmbGenere.Location = New-Object System.Drawing.Point(530, 108); $global:cmbGenere.Size = New-Object System.Drawing.Size(240, 26)
$global:cmbGenere.BackColor = [System.Drawing.Color]::Black; $global:cmbGenere.ForeColor = [System.Drawing.Color]::Lime; $global:cmbGenere.DropDownStyle = "DropDown"
$gbTags.Controls.Add($global:cmbGenere)

# Riga 4: Anno e Traccia
$lblAnno = New-Object System.Windows.Forms.Label; $lblAnno.Text = "Anno:"; $lblAnno.Location = New-Object System.Drawing.Point(20, 150); $lblAnno.Size = New-Object System.Drawing.Size(80, 20); $gbTags.Controls.Add($lblAnno)
$global:txtAnno = New-Object System.Windows.Forms.TextBox; $global:txtAnno.Location = New-Object System.Drawing.Point(110, 148); $global:txtAnno.Size = New-Object System.Drawing.Size(100, 26)
$global:txtAnno.BackColor = [System.Drawing.Color]::Black; $global:txtAnno.ForeColor = [System.Drawing.Color]::Lime; $gbTags.Controls.Add($global:txtAnno)

$lblTraccia = New-Object System.Windows.Forms.Label; $lblTraccia.Text = "Traccia:"; $lblTraccia.Location = New-Object System.Drawing.Point(230, 150); $lblTraccia.Size = New-Object System.Drawing.Size(80, 20); $gbTags.Controls.Add($lblTraccia)
$global:txtTraccia = New-Object System.Windows.Forms.TextBox; $global:txtTraccia.Location = New-Object System.Drawing.Point(310, 148); $global:txtTraccia.Size = New-Object System.Drawing.Size(100, 26)
$global:txtTraccia.BackColor = [System.Drawing.Color]::Black; $global:txtTraccia.ForeColor = [System.Drawing.Color]::Lime; $gbTags.Controls.Add($global:txtTraccia)

# --- PULSANTI AZIONE ---
$global:btnSave = New-Object System.Windows.Forms.Button
$global:btnSave.Text = "▶  SALVA METADATI"
$global:btnSave.Location = New-Object System.Drawing.Point(20, 340)
$global:btnSave.Size = New-Object System.Drawing.Size(800, 45)
$global:btnSave.FlatStyle = "Flat"; $global:btnSave.BackColor = [System.Drawing.Color]::Black
$global:btnSave.ForeColor = [System.Drawing.Color]::Lime; $global:btnSave.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
$global:btnSave.FlatAppearance.BorderSize = 2; $global:btnSave.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($global:btnSave)

# --- LOG ---
$global:txtLog = New-Object System.Windows.Forms.TextBox
$global:txtLog.Multiline = $true; $global:txtLog.ScrollBars = "Vertical"; $global:txtLog.ReadOnly = $true
$global:txtLog.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10); $global:txtLog.ForeColor = [System.Drawing.Color]::Lime
$global:txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$global:txtLog.Location = New-Object System.Drawing.Point(20, 400); $global:txtLog.Size = New-Object System.Drawing.Size(800, 200)
$global:txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($global:txtLog)

function Write-ScreenLog {
    param([string]$Message, [string]$Color = "Lime")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $global:txtLog.AppendText("[$timestamp] $Message`r`n")
    $global:txtLog.SelectionStart = $global:txtLog.Text.Length
    $global:txtLog.ScrollToCaret()
    Write-Log $Message "INFO"
}

# --- STATUS BAR E EXIT ---
$global:lblStatus = New-Object System.Windows.Forms.Label
$global:lblStatus.Text = "> Pronto."
$global:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 0)
$global:lblStatus.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$global:lblStatus.Location = New-Object System.Drawing.Point(20, 615); $global:lblStatus.Size = New-Object System.Drawing.Size(700, 25)
$form.Controls.Add($global:lblStatus)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "EXIT"; $btnExit.Location = New-Object System.Drawing.Point(730, 610)
$btnExit.Size = New-Object System.Drawing.Size(90, 30); $btnExit.FlatStyle = "Flat"
$btnExit.BackColor = [System.Drawing.Color]::Black; $btnExit.ForeColor = [System.Drawing.Color]::Red
$btnExit.FlatAppearance.BorderColor = [System.Drawing.Color]::Red
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ---------------------------------------------------
# 					fine terzo blocco
# ---------------------------------------------------

# ============================================================
# FUNZIONE PER POPOLARE LE COMBOBOX DAL FILE XML
# ============================================================
function Update-ComboBoxes {
    # Artisti
    $global:cmbArtista.Items.Clear()
    foreach ($artista in $script:tagsData.Tags.ArtistiSingoli.Artista) {
        $global:cmbArtista.Items.Add($artista) | Out-Null
    }

    # Generi
    $global:cmbGenere.Items.Clear()
    foreach ($genere in $script:tagsData.Tags.Generi.Genere) {
        $global:cmbGenere.Items.Add($genere) | Out-Null
    }

    # Duetti
    $global:cmbDuetto.Items.Clear()
    $global:cmbDuetto.Items.Add("") | Out-Null # Opzione vuota per "nessun duetto"
    foreach ($duetto in $script:tagsData.Tags.Duetti.Duetto) {
        $global:cmbDuetto.Items.Add($duetto) | Out-Null
    }
    $global:cmbDuetto.SelectedIndex = 0
}

# ============================================================
# EVENTI DELLA GUI
# ============================================================

# SFOGLIA FILE MP3
$global:btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Seleziona file MP3"
    $dialog.Filter = "File MP3|*.mp3|Tutti i file|*.*"
    if ($dialog.ShowDialog() -eq "OK") {
        $global:txtFile.Text = $dialog.FileName
        
        # Leggi i tag e popola i campi
        $tags = Get-Mp3Tags -FilePath $dialog.FileName
        if ($tags) {
            $global:txtTitolo.Text = $tags.Titolo
            $global:txtAlbum.Text = $tags.Album
            $global:txtAnno.Text = $tags.Anno
            $global:txtTraccia.Text = $tags.Traccia
            
            # Imposta l'Artista
            if ($tags.Artista) {
                # Se l'artista non è nella lista, aggiungilo temporaneamente alla ComboBox
                if (-not $global:cmbArtista.Items.Contains($tags.Artista)) {
                    $global:cmbArtista.Items.Add($tags.Artista) | Out-Null
                }
                $global:cmbArtista.SelectedItem = $tags.Artista
            } else {
                $global:cmbArtista.Text = ""
            }

            # Imposta il Genere
            if ($tags.Genere) {
                if (-not $global:cmbGenere.Items.Contains($tags.Genere)) {
                    $global:cmbGenere.Items.Add($tags.Genere) | Out-Null
                }
                $global:cmbGenere.SelectedItem = $tags.Genere
            } else {
                $global:cmbGenere.Text = ""
            }

            # Gestione Duetto (se il tag Artista contiene "feat." o "&")
            $global:cmbDuetto.SelectedIndex = 0
            if ($tags.Artista -match '(?i)feat\.|&|vs\.') {
                $duettoMatch = $global:cmbDuetto.Items | Where-Object { $_ -eq $tags.Artista }
                if ($duettoMatch) { $global:cmbDuetto.SelectedItem = $tags.Artista }
            }

            Write-ScreenLog "Tag letti da: $(Split-Path $dialog.FileName -Leaf)" "Cyan"
            $global:lblStatus.Text = "> File caricato. Modifica i campi e salva."
        } else {
            Write-ScreenLog "Impossibile leggere i tag dal file." "Red"
        }
    }
})

# SALVA METADATI
$global:btnSave.Add_Click({
    $filePath = $global:txtFile.Text.Trim()
    if (-not $filePath -or -not (Test-Path $filePath)) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un file MP3 valido.", "MATRIX - ATTENZIONE", "OK", "Warning") | Out-Null
        return
    }

    $titolo = $global:txtTitolo.Text.Trim()
    $album = $global:txtAlbum.Text.Trim()
    $anno = 0; [int]::TryParse($global:txtAnno.Text, [ref]$anno) | Out-Null
    $traccia = 0; [int]::TryParse($global:txtTraccia.Text, [ref]$traccia) | Out-Null

    # Gestione Artista e Duetto (Logica di priorità)
    $artistaFinale = ""
    if ($global:cmbDuetto.SelectedIndex -gt 0 -and $global:cmbDuetto.SelectedItem) {
        # Se è selezionato un duetto, usa quello come artista finale
        $artistaFinale = $global:cmbDuetto.SelectedItem.ToString()
    } else {
        # Altrimenti usa l'artista singolo
        $artistaFinale = $global:cmbArtista.Text.Trim()
    }

    $genereFinale = $global:cmbGenere.Text.Trim()

    # Applica il filtro di sanità mentale
    $artistaFinale = Format-TagValue $artistaFinale
    $genereFinale = Format-TagValue $genereFinale

    # Salva i tag nel file
    $success = Set-Mp3Tags -FilePath $filePath -Titolo $titolo -Artista $artistaFinale -Album $album -Genere $genereFinale -Anno $anno -Traccia $traccia

    if ($success) {
        Write-ScreenLog "Tag salvati con successo per: $(Split-Path $filePath -Leaf)" "Lime"
        
        # Auto-apprendimento (Opzione B)
        $newItems = $false
        
        # Controlla se l'artista è nuovo
        if ($artistaFinale -and -not (Test-TagInXml -Value $artistaFinale -Category "Artista")) {
            # Se è un duetto, aggiungilo ai Duetti e scomponi i nomi
            if ($artistaFinale -match '(?i)feat\.|&|vs\.') {
                Add-TagToXml -Value $artistaFinale -Category "Duetto"
                # Prova a estrarre i nomi singoli
                $nomi = $artistaFinale -split '(?i)feat\.|&|vs\.'
                foreach ($nome in $nomi) {
                    $nomePulito = Format-TagValue $nome
                    if ($nomePulito) { Add-TagToXml -Value $nomePulito -Category "Artista" }
                }
            } else {
                Add-TagToXml -Value $artistaFinale -Category "Artista"
            }
            $newItems = $true
        }

        # Controlla se il genere è nuovo
        if ($genereFinale -and -not (Test-TagInXml -Value $genereFinale -Category "Genere")) {
            Add-TagToXml -Value $genereFinale -Category "Genere"
            $newItems = $true
        }

        # Se ci sono nuovi elementi, salva l'XML e aggiorna le ComboBox
        if ($newItems) {
            Save-TagsXml
            Update-ComboBoxes
            Write-ScreenLog "Nuovi elementi aggiunti al catalogo tags.xml." "Cyan"
        }

        $global:lblStatus.Text = "> Metadati salvati."
    } else {
        Write-ScreenLog "Errore nel salvataggio dei metadati." "Red"
        $global:lblStatus.Text = "> Errore nel salvataggio."
    }
})

# ============================================================
# AVVIO FORM
# ============================================================
$form.Add_Load({
    Write-ScreenLog "JOE COLTON ID3 EDITOR v1.0 avviato." "Lime"
    Write-ScreenLog "Log file: $(Split-Path $script:logFile -Leaf)" "Cyan"
    Write-ScreenLog "Catalogo tags: $($script:tagsFilePath)" "Cyan"
    
    # Popola le ComboBox con i dati dal file XML
    Update-ComboBoxes
    
    $global:lblStatus.Text = "> Pronto. Seleziona un file MP3."
})

# Avvio della GUI
[void]$form.ShowDialog()
