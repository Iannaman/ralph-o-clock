<# : chooser
@echo off
setlocal
set "BATDIR=%~dp0"
set "BATFILE=%~f0"
rem Avvio senza console nera e con log degli errori
start "" powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "try { iex (Get-Content -LiteralPath '%~f0' -Raw) } catch { $_.Exception | Out-File '%~dp0error_log.txt' }"
exit /b
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configurazione File e Icona ---
$cartellaScript = $env:BATDIR
if ([string]::IsNullOrWhiteSpace($cartellaScript)) { $cartellaScript = [System.IO.Directory]::GetCurrentDirectory() }
$fileImpostazioni = Join-Path $cartellaScript "dati\settings.txt"
$fileCSV = Join-Path $cartellaScript "dati\registro_orari.csv" # Consiglio di spostare anche questo in dati!
$iconPath = Join-Path $cartellaScript "img\ralph.ico"
$imgPath = Join-Path $cartellaScript "img\ralph.png"
$audioPath = Join-Path $cartellaScript "audio\Ralph-bark.wav"
$audioAlarmPath = Join-Path $cartellaScript "audio\let-the-dogs-out.wav"


### funziona salva memoria
$settingsPath = Join-Path $cartellaScript "dati\settings.txt"

function Save-Settings {
    "$($chkStretch.Checked)|$($txtStretchMin.Text)|$($chkAutoStart.Checked)" | Out-File $settingsPath
}

function Load-Settings {
    if (Test-Path $settingsPath) {
        $data = (Get-Content $settingsPath).Split('|')
        
        
        $chkStretch.Checked = [bool]::Parse($data[0])
        
        
        $txtStretchMin.Text = $data[1]
        
        
        $chkAutoStart.Checked = [bool]::Parse($data[2])
        
    }
}

# --- Funzione Audio ---
function Play-StartupSound {
    if (Test-Path $audioPath) {
        #job in background
        Start-Job -ScriptBlock {
            $player = New-Object System.Media.SoundPlayer($using:audioPath)
            $player.PlaySync() 
        } | Out-Null
    }
}

function Play-AlarmSound {
    if (Test-Path $audioAlarmPath) {
        $player = New-Object System.Media.SoundPlayer($audioAlarmPath)
        $player.Play()
    } else {
        # Fallback se il file manca
        for ($i=0; $i -lt 5; $i++) { [System.Console]::Beep(880, 400); Start-Sleep -Milliseconds 200 }
    }
}

# --- Configurazione File di Database ---
$cartellaScript = $env:BATDIR
if ([string]::IsNullOrWhiteSpace($cartellaScript)) { $cartellaScript = [System.IO.Directory]::GetCurrentDirectory() }
$script:csvPath = Join-Path $cartellaScript "dati\registro_orari.csv"

# --- Configurazione Stile ---
$fontLabel = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$fontLabelBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$bgColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

$script:orarioUscitaSveglia = $null
$script:ultimoConsuntivo = $null

# --- Finestra Principale ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Ralph-o-Clock - Registro Orari & Umore - v.2.1" 
$form.Size = New-Object System.Drawing.Size(1100, 830)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $bgColor

# === INSERIMENTO IMMAGINE RALPH NEL FORM ===
$picRalph = New-Object System.Windows.Forms.PictureBox
# Posizionata in alto a destra
$picRalph.Location = New-Object System.Drawing.Point(300, 20) 
$picRalph.Size = New-Object System.Drawing.Size(100, 100)
$picRalph.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage

# Costruisce il percorso e carica direttamente il file PNG
$pngPath = Join-Path $cartellaScript "img\ralph.png"
if (Test-Path $pngPath) {
    $picRalph.Image = [System.Drawing.Image]::FromFile($pngPath)
}

$form.Controls.Add($picRalph)
# ===========================================
# ===========================================


# --- Icona Tray e Timer ---
$sysTrayIcon = New-Object System.Windows.Forms.NotifyIcon
$sysTrayIcon.Text = "Ralph-o-Clock"

# Applica ralph.ico sia alla Finestra che al System Tray
if (Test-Path $iconPath) {
    $customIcon = New-Object System.Drawing.Icon($iconPath)
    $form.Icon = $customIcon
    $sysTrayIcon.Icon = $customIcon
} else {
    $sysTrayIcon.Icon = [System.Drawing.SystemIcons]::Information
}

$sysTrayIcon.Visible = $false
$alarmTimer = New-Object System.Windows.Forms.Timer
$alarmTimer.Interval = 1000

# =========================================================================
# PANNELLO SINISTRO: INPUT E CALCOLO
# =========================================================================

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Configurazione e Calcolo"
$lblTitle.Font = $fontTitle
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(360, 30)
$form.Controls.Add($lblTitle)

$lblData = New-Object System.Windows.Forms.Label
$lblData.Text = "Data Riferimento:"
$lblData.Font = $fontLabel
$lblData.Location = New-Object System.Drawing.Point(20, 50)
$lblData.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($lblData)

$dtpData = New-Object System.Windows.Forms.DateTimePicker
$dtpData.Location = New-Object System.Drawing.Point(20, 70)
$dtpData.Size = New-Object System.Drawing.Size(120, 25)
$dtpData.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
$form.Controls.Add($dtpData)

$lblEntrata = New-Object System.Windows.Forms.Label
$lblEntrata.Text = "Orario di Entrata (HH:MM):"
$lblEntrata.Font = $fontLabel
$lblEntrata.Location = New-Object System.Drawing.Point(20, 100)
$lblEntrata.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($lblEntrata)

$txtEntrata = New-Object System.Windows.Forms.TextBox
$txtEntrata.Location = New-Object System.Drawing.Point(20, 120)
$txtEntrata.Size = New-Object System.Drawing.Size(120, 25)
$txtEntrata.Text = [DateTime]::Now.ToString("HH:mm")
$form.Controls.Add($txtEntrata)

$lblOre = New-Object System.Windows.Forms.Label
$lblOre.Text = "Orario Contrattuale:"
$lblOre.Font = $fontLabel
$lblOre.Location = New-Object System.Drawing.Point(20, 150)
$lblOre.Size = New-Object System.Drawing.Size(280, 20)
$form.Controls.Add($lblOre)

$txtOre = New-Object System.Windows.Forms.TextBox
$txtOre.Location = New-Object System.Drawing.Point(20, 170)
$txtOre.Size = New-Object System.Drawing.Size(120, 25)
$txtOre.Text = "07:12"
$form.Controls.Add($txtOre)

$lblInizioPausa = New-Object System.Windows.Forms.Label
$lblInizioPausa.Text = "Inizio Pausa (12:30 - 15:00):"
$lblInizioPausa.Font = $fontLabel
$lblInizioPausa.Location = New-Object System.Drawing.Point(20, 200)
$lblInizioPausa.Size = New-Object System.Drawing.Size(280, 20)
$form.Controls.Add($lblInizioPausa)

$txtInizioPausa = New-Object System.Windows.Forms.TextBox
$txtInizioPausa.Location = New-Object System.Drawing.Point(20, 220)
$txtInizioPausa.Size = New-Object System.Drawing.Size(120, 25)
$txtInizioPausa.Text = "13:00"
$form.Controls.Add($txtInizioPausa)

$lblFinePausa = New-Object System.Windows.Forms.Label
$lblFinePausa.Text = "Fine Pausa:"
$lblFinePausa.Font = $fontLabel
$lblFinePausa.Location = New-Object System.Drawing.Point(20, 250)
$lblFinePausa.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($lblFinePausa)

$txtFinePausa = New-Object System.Windows.Forms.TextBox
$txtFinePausa.Location = New-Object System.Drawing.Point(20, 270)
$txtFinePausa.Size = New-Object System.Drawing.Size(120, 25)
$txtFinePausa.Text = "13:30"
$form.Controls.Add($txtFinePausa)

$lblUscitaEff = New-Object System.Windows.Forms.Label
$lblUscitaEff.Text = "Uscita Effettiva (Opzionale):"
$lblUscitaEff.Font = $fontLabelBold
$lblUscitaEff.Location = New-Object System.Drawing.Point(20, 300)
$lblUscitaEff.Size = New-Object System.Drawing.Size(280, 20)
$form.Controls.Add($lblUscitaEff)

$txtUscitaEff = New-Object System.Windows.Forms.TextBox
$txtUscitaEff.Location = New-Object System.Drawing.Point(20, 320)
$txtUscitaEff.Size = New-Object System.Drawing.Size(120, 25)
$txtUscitaEff.Text = "" 
$form.Controls.Add($txtUscitaEff)

# --- Tracking Umore (Soluzione ASCII/Testo) ---
$lblUmore = New-Object System.Windows.Forms.Label
$lblUmore.Text = "Umore del Giorno:"
$lblUmore.Font = $fontLabelBold
$lblUmore.Location = New-Object System.Drawing.Point(20, 355)
$lblUmore.Size = New-Object System.Drawing.Size(130, 20)
$form.Controls.Add($lblUmore)

$btnInfoUmore = New-Object System.Windows.Forms.Button
$btnInfoUmore.Text = "?"
$btnInfoUmore.Location = New-Object System.Drawing.Point(150, 352)
$btnInfoUmore.Size = New-Object System.Drawing.Size(25, 25)
$btnInfoUmore.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnInfoUmore.BackColor = [System.Drawing.Color]::LightBlue
$btnInfoUmore.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnInfoUmore)

$cbUmore = New-Object System.Windows.Forms.ComboBox
$cbUmore.Location = New-Object System.Drawing.Point(20, 375)
$cbUmore.Size = New-Object System.Drawing.Size(360, 25)
$cbUmore.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbUmore.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$cbUmore.Items.Add("[ ^_^ ] Energico & Positivo") | Out-Null
$cbUmore.Items.Add("[ </> ] Lavoratore & Impegnato") | Out-Null
$cbUmore.Items.Add("[ ~_~ ] Calmo & Rilassato") | Out-Null
$cbUmore.Items.Add("[ T_T ] Triste & Sottotono") | Out-Null
$form.Controls.Add($cbUmore)

# --- Note Giornaliere ---
$lblNote = New-Object System.Windows.Forms.Label
$lblNote.Text = "Note (Max 1600 car.):"
$lblNote.Font = $fontLabel
$lblNote.Location = New-Object System.Drawing.Point(20, 410)
$lblNote.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($lblNote)

$txtNote = New-Object System.Windows.Forms.TextBox
$txtNote.Location = New-Object System.Drawing.Point(20, 430)
$txtNote.Size = New-Object System.Drawing.Size(360, 50)
$txtNote.Multiline = $true
$txtNote.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtNote.MaxLength = 1600
$form.Controls.Add($txtNote)

# --- Bottoni Elabora / Sveglia ---
$btnCalcola = New-Object System.Windows.Forms.Button
$btnCalcola.Text = "Elabora Dati"
$btnCalcola.Location = New-Object System.Drawing.Point(20, 490)
$btnCalcola.Size = New-Object System.Drawing.Size(110, 35)
$btnCalcola.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnCalcola.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnCalcola.ForeColor = [System.Drawing.Color]::White
$btnCalcola.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnCalcola)

$btnSveglia = New-Object System.Windows.Forms.Button
$btnSveglia.Text = "Attiva Sveglia"
$btnSveglia.Location = New-Object System.Drawing.Point(140, 490)
$btnSveglia.Size = New-Object System.Drawing.Size(110, 35)
$btnSveglia.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSveglia.BackColor = [System.Drawing.Color]::DarkGray
$btnSveglia.ForeColor = [System.Drawing.Color]::White
$btnSveglia.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSveglia.Enabled = $false
$form.Controls.Add($btnSveglia)

$btnStopSveglia = New-Object System.Windows.Forms.Button
$btnStopSveglia.Text = "Stop Sveglia"
$btnStopSveglia.Location = New-Object System.Drawing.Point(260, 490)
$btnStopSveglia.Size = New-Object System.Drawing.Size(120, 35)
$btnStopSveglia.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnStopSveglia.BackColor = [System.Drawing.Color]::DarkGray
$btnStopSveglia.ForeColor = [System.Drawing.Color]::White
$btnStopSveglia.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStopSveglia.Enabled = $false
$form.Controls.Add($btnStopSveglia)

# === NUOVA FUNZIONE: SGRANCHISCI GAMBE ===
$chkStretch = New-Object System.Windows.Forms.CheckBox
$chkStretch.Text = "Sgranchisci gambe ogni:"
$chkStretch.Location = New-Object System.Drawing.Point(20, 535)
$chkStretch.Size = New-Object System.Drawing.Size(170, 20)
$chkStretch.Font = $fontLabelBold
$form.Controls.Add($chkStretch)

$txtStretchMin = New-Object System.Windows.Forms.TextBox
$txtStretchMin.Location = New-Object System.Drawing.Point(180, 533)
$txtStretchMin.Size = New-Object System.Drawing.Size(35, 20)
$txtStretchMin.Text = "45"
$txtStretchMin.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$form.Controls.Add($txtStretchMin)

$lblStretchMin = New-Object System.Windows.Forms.Label
$lblStretchMin.Text = "minuti (Ralph abbaia)"
$lblStretchMin.Location = New-Object System.Drawing.Point(220, 535)
$lblStretchMin.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($lblStretchMin)

$stretchTimer = New-Object System.Windows.Forms.Timer
$chkStretch.Add_CheckedChanged({
    if ($chkStretch.Checked) {
        $minuti = 45
        if ([int]::TryParse($txtStretchMin.Text, [ref]$minuti) -and $minuti -gt 0) {
            $stretchTimer.Interval = $minuti * 60 * 1000
            $stretchTimer.Start()
            $txtStretchMin.Enabled = $false # Blocca il testo finch� � attivo
        } else {
            [System.Windows.Forms.MessageBox]::Show("Inserisci un numero valido di minuti.", "Errore", 0, 16)
            $chkStretch.Checked = $false
        }
    } else {
        $stretchTimer.Stop()
        $txtStretchMin.Enabled = $true
    }
    Save-Settings
})

# Quando il timer scatta, riproduce l'audio di Ralph senza bloccare il programma
$stretchTimer.Add_Tick({
    try { Play-StartupSound } catch {}
})
# =========================================

# === CHECKBOX AVVIO AUTOMATICO ===
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$shortcutPath = [System.IO.Path]::Combine($startupFolder, "Ralph-o-Clock.lnk")

$chkAutoStart = New-Object System.Windows.Forms.CheckBox
$chkAutoStart.Text = "Avvio automatico all'accensione"
$chkAutoStart.Location = New-Object System.Drawing.Point(20, 550)
$chkAutoStart.Size = New-Object System.Drawing.Size(200, 30)
# Controlla se il file esiste per impostare lo stato iniziale
$chkAutoStart.Checked = (Test-Path $shortcutPath)
$form.Controls.Add($chkAutoStart)

$chkAutoStart.Add_CheckedChanged({
    if ($chkAutoStart.Checked) {
        # Crea il collegamento
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $env:BATFILE
        $shortcut.WorkingDirectory = $env:BATDIR
        $shortcut.Save()
    } else {
        # Rimuove il collegamento
        if (Test-Path $shortcutPath) { Remove-Item $shortcutPath }
    }
    Save-Settings
})# =========================================AUTOSTART


# === NUOVA FUNZIONE: CANE DA GUARDIA (TEAMS VERDE) ===
$chkAwake = New-Object System.Windows.Forms.CheckBox
$chkAwake.Text = "Cane da guardia"
$chkAwake.Location = New-Object System.Drawing.Point(220, 555)
$chkAwake.Size = New-Object System.Drawing.Size(120, 20)
$chkAwake.Font = $fontLabelBold
$chkAwake.ForeColor = [System.Drawing.Color]::ForestGreen
$form.Controls.Add($chkAwake)

$btnInfoAwake = New-Object System.Windows.Forms.Button
$btnInfoAwake.Text = "?"
$btnInfoAwake.Location = New-Object System.Drawing.Point(350, 552)
$btnInfoAwake.Size = New-Object System.Drawing.Size(25, 25)
$btnInfoAwake.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnInfoAwake.BackColor = [System.Drawing.Color]::LightGreen
$btnInfoAwake.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnInfoAwake)

$btnInfoAwake.Add_Click({
    $msg = " Modalita' Cane da Guardia `n`nQuando questa opzione e' attiva, Ralph fa credere al PC che tu sia presente.`n`nRisultato:`n- Schermo sempre acceso.`n- Pallino di Microsoft Teams sempre VERDE (Disponibile)!"
    [System.Windows.Forms.MessageBox]::Show($msg, "Cane da Guardia", 0, 64)
})

$awakeTimer = New-Object System.Windows.Forms.Timer
$awakeTimer.Interval = 120000 # 120.000 millisecondi = 2 minuti

$chkAwake.Add_CheckedChanged({
    # Definisce i percorsi delle nuove icone e immagini
    $iconPathGuardia = Join-Path $cartellaScript "img\Ralph-cane-guardia.ico"
    $pngPathGuardia = Join-Path $cartellaScript "img\Ralph-cane-guardia.png"
    
    # Percorso dell'immagine originale
    $pngPathStandard = Join-Path $cartellaScript "img\ralph.png"
    
    if ($chkAwake.Checked) {
        $awakeTimer.Start()
        $sysTrayIcon.Text = "Cane guardia attivo"
        
        # Imposta l'icona nella barra delle applicazioni
        if (Test-Path $iconPathGuardia) {
            $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPathGuardia)
        }
        
        # Cambia l'immagine all'interno del Form principale
        if (Test-Path $pngPathGuardia) {
            $picRalph.Image = [System.Drawing.Image]::FromFile($pngPathGuardia)
        }
    } else {
        $awakeTimer.Stop()
        $sysTrayIcon.Text = "Cane guardia disattivo"
        
        # Ripristina l'icona standard di Ralph nella barra
        if (Test-Path $iconPath) {
            $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPath)
        } else {
            $sysTrayIcon.Icon = [System.Drawing.SystemIcons]::Information
        }
        
        # Ripristina l'immagine standard all'interno del Form
        if (Test-Path $pngPathStandard) {
            $picRalph.Image = [System.Drawing.Image]::FromFile($pngPathStandard)
        }
    }
})

$awakeTimer.Add_Tick({
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.SendKeys('{F15}')
    } catch {}
})
# =======================================================




# --- MODIFICA SPAZIATURA PER $rtbRisultato ---
$rtbRisultato = New-Object System.Windows.Forms.RichTextBox
$rtbRisultato.Location = New-Object System.Drawing.Point(20, 575)  # Spostato in basso
$rtbRisultato.Size = New-Object System.Drawing.Size(360, 110)      # Rimpicciolito
$rtbRisultato.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
$rtbRisultato.ReadOnly = $true
$rtbRisultato.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$rtbRisultato.BackColor = $bgColor
$form.Controls.Add($rtbRisultato)

$btnSalvaRegistro = New-Object System.Windows.Forms.Button
$btnSalvaRegistro.Text = "Salva in Registro (Sovrascrive se data esiste)"
$btnSalvaRegistro.Location = New-Object System.Drawing.Point(20, 685)
$btnSalvaRegistro.Size = New-Object System.Drawing.Size(360, 35)
$btnSalvaRegistro.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnSalvaRegistro.BackColor = [System.Drawing.Color]::DarkGray
$btnSalvaRegistro.ForeColor = [System.Drawing.Color]::White
$btnSalvaRegistro.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSalvaRegistro.Enabled = $false
$form.Controls.Add($btnSalvaRegistro)

# --- Pulsanti Aggiuntivi: Supporto e Start Menu ---
$btnSupporto = New-Object System.Windows.Forms.Button
$btnSupporto.Text = "[@] Richiedi Supporto"
$btnSupporto.Location = New-Object System.Drawing.Point(20, 730)
$btnSupporto.Size = New-Object System.Drawing.Size(175, 35)
$btnSupporto.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSupporto.BackColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
$btnSupporto.ForeColor = [System.Drawing.Color]::White
$btnSupporto.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnSupporto)

$btnStartMenu = New-Object System.Windows.Forms.Button
$btnStartMenu.Text = "[+] Aggiungi a Start"
$btnStartMenu.Location = New-Object System.Drawing.Point(205, 730)
$btnStartMenu.Size = New-Object System.Drawing.Size(175, 35)
$btnStartMenu.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnStartMenu.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$btnStartMenu.ForeColor = [System.Drawing.Color]::White
$btnStartMenu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnStartMenu)

# =========================================================================
# PANNELLO DESTRO: TABELLA, FILTRI, BILANCIO GLOBALE E STAT. UMORE
# =========================================================================



$lblTitleReg = New-Object System.Windows.Forms.Label
$lblTitleReg.Text = "Registro Storico (Modificabile in griglia)"
$lblTitleReg.Font = $fontTitle
$lblTitleReg.Location = New-Object System.Drawing.Point(410, 15)
$lblTitleReg.Size = New-Object System.Drawing.Size(500, 25)
$form.Controls.Add($lblTitleReg)

$flpMesi = New-Object System.Windows.Forms.FlowLayoutPanel
$flpMesi.Location = New-Object System.Drawing.Point(410, 45)
$flpMesi.Size = New-Object System.Drawing.Size(660, 35)
$flpMesi.WrapContents = $false
$form.Controls.Add($flpMesi)

$btnTuttiMesi = New-Object System.Windows.Forms.Button
$btnTuttiMesi.Text = "Tutti"
$btnTuttiMesi.Size = New-Object System.Drawing.Size(50, 28)
$btnTuttiMesi.BackColor = [System.Drawing.Color]::LightGray
$btnTuttiMesi.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnTuttiMesi.Add_Click({ 
    $dt.DefaultView.RowFilter = ""
    Aggiorna-StatisticheUmore
})
$flpMesi.Controls.Add($btnTuttiMesi)

$mesiNomi = @("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")
for ($i=0; $i -lt 12; $i++) {
    $btnMese = New-Object System.Windows.Forms.Button
    $btnMese.Text = $mesiNomi[$i]
    $btnMese.Size = New-Object System.Drawing.Size(44, 28)
    $btnMese.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMese.BackColor = [System.Drawing.Color]::White
    $meseStr = ($i+1).ToString("00")
    $scriptBlock = [scriptblock]::Create("`$dt.DefaultView.RowFilter = `"Data LIKE '%/$meseStr/%'`"; Aggiorna-StatisticheUmore")
    $btnMese.Add_Click($scriptBlock)
    $flpMesi.Controls.Add($btnMese)
}

$dgv = New-Object System.Windows.Forms.DataGridView
$dgv.Location = New-Object System.Drawing.Point(410, 85)
$dgv.Size = New-Object System.Drawing.Size(650, 440)
$dgv.BackgroundColor = [System.Drawing.Color]::White
$dgv.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$dgv.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$dgv.AllowUserToAddRows = $false
$dgv.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$form.Controls.Add($dgv)

$dt = New-Object System.Data.DataTable
[void]$dt.Columns.Add("Data")
[void]$dt.Columns.Add("Entrata")
[void]$dt.Columns.Add("Pausa (Min)")
[void]$dt.Columns.Add("Uscita")
[void]$dt.Columns.Add("Effettivo")
[void]$dt.Columns.Add("Flessibilita")
[void]$dt.Columns.Add("Ticket")
[void]$dt.Columns.Add("Umore")
[void]$dt.Columns.Add("Note")
$dgv.DataSource = $dt

$lblBilancioMensile = New-Object System.Windows.Forms.Label
$lblBilancioMensile.Location = New-Object System.Drawing.Point(410, 535)
$lblBilancioMensile.Size = New-Object System.Drawing.Size(630, 30)
$lblBilancioMensile.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblBilancioMensile.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblBilancioMensile.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblBilancioMensile.Text = " Bilancio Totale (Tutti i Mesi): In Calcolo..."
$lblBilancioMensile.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($lblBilancioMensile)

# --- Campo Statistica Umore ---
$lblStatUmore = New-Object System.Windows.Forms.Label
$lblStatUmore.Location = New-Object System.Drawing.Point(410, 575)
$lblStatUmore.Size = New-Object System.Drawing.Size(630, 60)
$lblStatUmore.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$lblStatUmore.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblStatUmore.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblStatUmore.BackColor = [System.Drawing.Color]::FromArgb(240, 249, 255) 
$lblStatUmore.Text = "Statistica Umore Mensile: In Calcolo..."
$form.Controls.Add($lblStatUmore)

# --- Bottoni Gestione Tabella ---
$btnUpdateTabella = New-Object System.Windows.Forms.Button
$btnUpdateTabella.Text = "Salva Modifiche Tabella"
$btnUpdateTabella.Location = New-Object System.Drawing.Point(410, 650)
$btnUpdateTabella.Size = New-Object System.Drawing.Size(180, 35)
$btnUpdateTabella.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnUpdateTabella.BackColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
$btnUpdateTabella.ForeColor = [System.Drawing.Color]::White
$btnUpdateTabella.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnUpdateTabella)

$btnEliminaRiga = New-Object System.Windows.Forms.Button
$btnEliminaRiga.Text = "Elimina Riga"
$btnEliminaRiga.Location = New-Object System.Drawing.Point(600, 650)
$btnEliminaRiga.Size = New-Object System.Drawing.Size(120, 35)
$btnEliminaRiga.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnEliminaRiga.BackColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
$btnEliminaRiga.ForeColor = [System.Drawing.Color]::White
$btnEliminaRiga.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnEliminaRiga)

$btnSvuotaDB = New-Object System.Windows.Forms.Button
$btnSvuotaDB.Text = "Svuota Intero Database"
$btnSvuotaDB.Location = New-Object System.Drawing.Point(730, 650)
$btnSvuotaDB.Size = New-Object System.Drawing.Size(310, 35)
$btnSvuotaDB.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSvuotaDB.BackColor = [System.Drawing.Color]::Black
$btnSvuotaDB.ForeColor = [System.Drawing.Color]::White
$btnSvuotaDB.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnSvuotaDB)

$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Text = "Credits: Danilo Iannello"
$lblCredits.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblCredits.Location = New-Object System.Drawing.Point(410, 745)
$lblCredits.Size = New-Object System.Drawing.Size(630, 20)
$lblCredits.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblCredits.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($lblCredits)

# =========================================================================
# FUNZIONI LOGICHE E GESTIONE DATI
# =========================================================================

$btnStartMenu.Add_Click({
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $percorsoStart = [Environment]::GetFolderPath("StartMenu") + "\Programs\Ralph-o-Clock.lnk"
        $Shortcut = $WshShell.CreateShortcut($percorsoStart)
        $Shortcut.TargetPath = $env:BATFILE
        $Shortcut.WorkingDirectory = $env:BATDIR
        $Shortcut.IconLocation = "shell32.dll,43"
        $Shortcut.Save()
        [System.Windows.Forms.MessageBox]::Show("Ralph-o-Clock aggiunto a Start!", "Fatto!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Impossibile creare il collegamento. Assicurati di avere i permessi.", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnInfoUmore.Add_Click({
    $testoInfo = "Tracking Umore - gli eruditi lo chiamerebbero 'Bestemmiometro', ma questa e' un'altra storia...:`n`n" +
    "[ ^_^ ] Energico & Positivo`nTi senti pieno di carica, ottimista e pronto a spaccare il mondo.`n`n" +
    "[ </> ] Lavoratore & Impegnato`nSei focalizzato sui tuoi obiettivi, super produttivo e con la mente totalmente immersa nei progetti o nel codice.`n`n" +
    "[ ~_~ ] Calmo & Rilassato`nCerchi tranquillita', ritmi lenti e momenti per te. Ti senti in pace.`n`n" +
    "[ T_T ] Triste & Sottotono`nHai le pile scariche, ti senti un po' malinconico, stanco o sopraffatto."
    
    [System.Windows.Forms.MessageBox]::Show($testoInfo, "Tracking Umore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

function Aggiorna-StatisticheUmore {
    $totale = 0
    $cE = 0; $cL = 0; $cC = 0; $cT = 0
    
    foreach ($drv in $dt.DefaultView) {
        $umore = $drv["Umore"].ToString()
        if (-not [string]::IsNullOrWhiteSpace($umore)) {
            $totale++
            if ($umore -match "Energico") { $cE++ }
            elseif ($umore -match "Lavoratore") { $cL++ }
            elseif ($umore -match "Calmo") { $cC++ }
            elseif ($umore -match "Triste") { $cT++ }
        }
    }
    
    if ($totale -gt 0) {
        $pE = [Math]::Round(($cE / $totale) * 100)
        $pL = [Math]::Round(($cL / $totale) * 100)
        $pC = [Math]::Round(($cC / $totale) * 100)
        $pT = [Math]::Round(($cT / $totale) * 100)
        
        $lblStatUmore.Text = "Statistica Umore:`n" +
            "$pE% [ ^_^ ] Energico & Positivo   |   $pL% [ </> ] Lavoratore & Impegnato`n" +
            "$pC% [ ~_~ ] Calmo & Rilassato   |   $pT% [ T_T ] Triste & Sottotono"
    } else {
        $lblStatUmore.Text = "Statistica Umore:`nNessun dato registrato nel periodo selezionato."
    }
}

function Calcola-BilancioGlobale {
    $totaleMinuti = 0
    foreach ($row in $dt.Rows) {
        $flesText = $row["Flessibilita"].ToString().Split(' ')[0].Trim()
        if ($flesText -match "^([+-])(\d{2}):(\d{2})$") {
            $segno = $matches[1]
            $ore = [int]$matches[2]
            $minuti = [int]$matches[3]
            $minutiTotali = ($ore * 60) + $minuti
            if ($segno -eq "+") { $totaleMinuti += $minutiTotali }
            else { $totaleMinuti -= $minutiTotali }
        }
    }
    
    $oreFinali = [Math]::Truncate([Math]::Abs($totaleMinuti) / 60)
    $minutiFinali = [Math]::Abs($totaleMinuti) % 60
    $stringaOraria = "{0:00}:{1:00}" -f $oreFinali, $minutiFinali
    
    if ($totaleMinuti -gt 0) {
        $lblBilancioMensile.Text = "Bilancio Totale (Tutti i Mesi): +$stringaOraria (Credito/Da Recuperare)"
        $lblBilancioMensile.ForeColor = [System.Drawing.Color]::FromArgb(21, 128, 61) 
        $lblBilancioMensile.BackColor = [System.Drawing.Color]::FromArgb(240, 253, 244)
    } elseif ($totaleMinuti -lt 0) {
        $lblBilancioMensile.Text = "Bilancio Totale (Tutti i Mesi): -$stringaOraria (Debito/Da Sanare)"
        $lblBilancioMensile.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28) 
        $lblBilancioMensile.BackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
    } else {
        $lblBilancioMensile.Text = "Bilancio Totale (Tutti i Mesi): 00:00 (In Pari)"
        $lblBilancioMensile.ForeColor = [System.Drawing.Color]::Black
        $lblBilancioMensile.BackColor = [System.Drawing.Color]::White
    }
    
    Aggiorna-StatisticheUmore
}

$dgv.Add_CellValueChanged({
    param($sender, $e)
    if ($e.RowIndex -lt 0 -or $dt -eq $null) { return }

    $colName = $dgv.Columns[$e.ColumnIndex].Name
    
    if ($colName -eq "Umore") {
        Aggiorna-StatisticheUmore
        return
    }
    
    if ($colName -eq "Entrata" -or $colName -eq "Uscita" -or $colName -eq "Pausa (Min)") {
        try {
            $drv = $dgv.Rows[$e.RowIndex].DataBoundItem
            if ($drv -eq $null) { return }
            $row = $drv.Row
            
            $strEntrata = $row["Entrata"].ToString().Trim()
            $strUscita = $row["Uscita"].ToString().Trim()
            $strPausa = $row["Pausa (Min)"].ToString().Trim()
            
            if ([string]::IsNullOrWhiteSpace($strEntrata) -or [string]::IsNullOrWhiteSpace($strUscita) -or $strUscita -eq "N/D") {
                Calcola-BilancioGlobale
                return
            }
            
            if ($strEntrata.Length -eq 4 -and $strEntrata -notmatch ":") { $strEntrata = $strEntrata.Substring(0,2) + ":" + $strEntrata.Substring(2,2); $row["Entrata"] = $strEntrata }
            if ($strUscita.Length -eq 4 -and $strUscita -notmatch ":") { $strUscita = $strUscita.Substring(0,2) + ":" + $strUscita.Substring(2,2); $row["Uscita"] = $strUscita }

            $oraEntrataInizians = [TimeSpan]::Parse($strEntrata)
            $oraUscitaTime = [TimeSpan]::Parse($strUscita)
            $pausaMin = [int]$strPausa
            $oreLavoroObbligatorie = [TimeSpan]::Parse($txtOre.Text)
            
            $sogliaMinEntrata = [TimeSpan]::Parse("07:30")
            $sogliaTicket = [TimeSpan]::Parse("06:30")
            
            $oraEntrataEffettiva = $oraEntrataInizians
            if ($oraEntrataInizians -lt $sogliaMinEntrata) { $oraEntrataEffettiva = $sogliaMinEntrata }
            
            $durataPausa = [TimeSpan]::FromMinutes($pausaMin)
            $oreLavorateEffettive = ($oraUscitaTime - $oraEntrataEffettiva) - $durataPausa
            
            $row["Effettivo"] = $oreLavorateEffettive.ToString("hh\:mm")
            if ($oreLavorateEffettive -ge $sogliaTicket) { $row["Ticket"] = "SI" } else { $row["Ticket"] = "NO" }
            
            $differenza = $oreLavorateEffettive - $oreLavoroObbligatorie
            if ($differenza.TotalMinutes -gt 0) {
                if ($differenza.TotalMinutes -gt 120) { $row["Flessibilita"] = "+02:00 (Tagliata)" }
                else { $row["Flessibilita"] = "+" + $differenza.ToString("hh\:mm") }
            } else {
                $row["Flessibilita"] = "-" + [TimeSpan]::FromMinutes([Math]::Abs($differenza.TotalMinutes)).ToString("hh\:mm")
            }
        } catch {}
    }
    
    Calcola-BilancioGlobale
})

function Correggi-FormatoOrario ($textBox) {
    $val = $textBox.Text.Trim()
    if ([string]::IsNullOrEmpty($val) -or $val.Contains(":")) { return }
    if ($val -match "^\d+$") {
        if ($val.Length -eq 1) { $val = "0" + $val + ":00" }
        elseif ($val.Length -eq 2) { $val = $val + ":00" }
        elseif ($val.Length -eq 3) { $val = "0" + $val.Substring(0,1) + ":" + $val.Substring(1,2) }
        elseif ($val.Length -eq 4) { $val = $val.Substring(0,2) + ":" + $val.Substring(2,2) }
    }
    $textBox.Text = $val
}

$txtEntrata.Add_LostFocus({ Correggi-FormatoOrario $txtEntrata })
$txtOre.Add_LostFocus({ Correggi-FormatoOrario $txtOre })
$txtInizioPausa.Add_LostFocus({ Correggi-FormatoOrario $txtInizioPausa })
$txtFinePausa.Add_LostFocus({ Correggi-FormatoOrario $txtFinePausa })
$txtUscitaEff.Add_LostFocus({ Correggi-FormatoOrario $txtUscitaEff })

function Append-ColoredText {
    param($rtb, $text, $color, $bold = $false)
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor = $color
    if ($bold) { $rtb.SelectionFont = New-Object System.Drawing.Font($rtb.Font, [System.Drawing.FontStyle]::Bold) } 
    else { $rtb.SelectionFont = New-Object System.Drawing.Font($rtb.Font, [System.Drawing.FontStyle]::Regular) }
    $rtb.AppendText($text)
    $rtb.SelectionColor = $rtb.ForeColor
}

function Carica-CSV {
    $dt.Rows.Clear()
    if (Test-Path $script:csvPath) {
        $righe = Import-Csv -Path $script:csvPath -Delimiter ";"
        foreach ($riga in $righe) {
            $row = $dt.NewRow()
            $row["Data"] = $riga.Data
            $row["Entrata"] = $riga.Entrata
            $row["Pausa (Min)"] = $riga."Pausa (Min)"
            $row["Uscita"] = $riga.Uscita
            $row["Effettivo"] = $riga.Effettivo
            $row["Flessibilita"] = $riga.Flessibilita
            $row["Ticket"] = $riga.Ticket
            if ($null -ne $riga.Umore) { $row["Umore"] = $riga.Umore }
            if ($null -ne $riga.Note) { $row["Note"] = $riga.Note }
            $dt.Rows.Add($row)
        }
    }
    Calcola-BilancioGlobale
}

function Salva-TabellaSuCSV {
    $lista = New-Object System.Collections.Generic.List[PSObject]
    foreach ($row in $dt.Rows) {
        $obj = [PSCustomObject]@{
            "Data"         = $row["Data"]
            "Entrata"      = $row["Entrata"]
            "Pausa (Min)"  = $row["Pausa (Min)"]
            "Uscita"       = $row["Uscita"]
            "Effettivo"    = $row["Effettivo"]
            "Flessibilita" = $row["Flessibilita"]
            "Ticket"       = $row["Ticket"]
            "Umore"        = $row["Umore"]
            "Note"         = $row["Note"]
        }
        $lista.Add($obj)
    }
    $lista | Export-Csv -Path $script:csvPath -Delimiter ";" -NoTypeInformation
    Calcola-BilancioGlobale
}

# =========================================================================
# INTEGRAZIONE POMODORO TIMER, IMPOSTAZIONI, DIARIO E TAB CONTROL
# =========================================================================
[console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- 0. Creazione Cartelle Organizzative ---
$cartelleApp = @("audio", "dati", "img")
foreach ($c in $cartelleApp) {
    $dirPath = Join-Path $cartellaScript $c
    if (-not (Test-Path $dirPath)) { New-Item -ItemType Directory -Force -Path $dirPath | Out-Null }
}

# --- 1. Gestione Impostazioni Audio Custom ---
$script:audioSettingsPath = Join-Path $cartellaScript "dati\audio_settings.txt"
$script:audioGambe = Join-Path $cartellaScript "audio\Ralph-bark.wav"
$script:audioSveglia = Join-Path $cartellaScript "audio\let-the-dogs-out.wav"
$script:audioPomoFine = Join-Path $cartellaScript "audio\let-the-dogs-out.wav"
$script:audioPomoPausa = Join-Path $cartellaScript "audio\Ralph-bark.wav"

function Load-AudioSettings {
    if (Test-Path $script:audioSettingsPath) {
        $lines = Get-Content $script:audioSettingsPath -Encoding UTF8
        if ($lines.Count -ge 4) {
            $script:audioGambe = $lines[0]
            $script:audioSveglia = $lines[1]
            $script:audioPomoFine = $lines[2]
            $script:audioPomoPausa = $lines[3]
        }
    }
}
function Save-AudioSettings {
    @($script:audioGambe, $script:audioSveglia, $script:audioPomoFine, $script:audioPomoPausa) | Set-Content -Path $script:audioSettingsPath -Encoding UTF8
}
Load-AudioSettings

function Play-StartupSound {
    if (Test-Path $script:audioGambe) {
        Start-Job -ScriptBlock { $player = New-Object System.Media.SoundPlayer($using:script:audioGambe); $player.PlaySync() } | Out-Null
    }
}
function Play-AlarmSound {
    if (Test-Path $script:audioSveglia) {
        $player = New-Object System.Media.SoundPlayer($script:audioSveglia); $player.Play()
    } else { for ($i=0; $i -lt 5; $i++) { [System.Console]::Beep(880, 400); Start-Sleep -Milliseconds 200 } }
}
function Play-PomoFineSound {
    if (Test-Path $script:audioPomoFine) {
        $player = New-Object System.Media.SoundPlayer($script:audioPomoFine); $player.Play()
    } else { Play-AlarmSound }
}
function Play-PomoPausaSound {
    if (Test-Path $script:audioPomoPausa) {
        $player = New-Object System.Media.SoundPlayer($script:audioPomoPausa); $player.Play()
    } else { Play-StartupSound }
}

# --- 2. Inizializzazione Tab Control ---
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(400, 15)
$tabControl.Size = New-Object System.Drawing.Size(660, 760)

$tabRegistro = New-Object System.Windows.Forms.TabPage
$tabRegistro.Text = "Registro Storico"
$tabRegistro.BackColor = $bgColor
$tabControl.TabPages.Add($tabRegistro)

$tabPomodoro = New-Object System.Windows.Forms.TabPage
$tabPomodoro.Text = "Pomodoro Timer"
$tabPomodoro.BackColor = $bgColor
$tabControl.TabPages.Add($tabPomodoro)

$tabDiario = New-Object System.Windows.Forms.TabPage
$tabDiario.Text = "Diario Agenda"
$tabDiario.BackColor = $bgColor
$tabControl.TabPages.Add($tabDiario)

$tabImpostazioni = New-Object System.Windows.Forms.TabPage
$tabImpostazioni.Text = "Impostazioni Audio"
$tabImpostazioni.BackColor = $bgColor
$tabControl.TabPages.Add($tabImpostazioni)

$form.Controls.Add($tabControl)

# --- Spostamento Dinamico Registro ---
$controlliDestri = @($lblTitleReg, $flpMesi, $dgv, $lblBilancioMensile, $lblStatUmore, $btnUpdateTabella , $btnEliminaRiga, $btnSvuotaDB)
foreach ($ctrl in $controlliDestri) {
    if ($null -ne $ctrl) {
        $form.Controls.Remove($ctrl)
        $ctrl.Location = New-Object System.Drawing.Point(($ctrl.Location.X - 400), ($ctrl.Location.Y - 15))
        $tabRegistro.Controls.Add($ctrl)
    }
}

# ---# --- 3. Setup Tab Impostazioni Audio ---

# Definiamo i TextBox a livello di script per "blindarli" ed evitare che perdano la proprietà .Text
$script:txtGambe = New-Object System.Windows.Forms.TextBox
$script:txtSveglia = New-Object System.Windows.Forms.TextBox
$script:txtPomoFine = New-Object System.Windows.Forms.TextBox
$script:txtPomoPausa = New-Object System.Windows.Forms.TextBox

function Crea-RigaAudio($labelText, $txtBox, $defaultPath, $y) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labelText
    $lbl.Location = New-Object System.Drawing.Point(20, $y)
    $lbl.Size = New-Object System.Drawing.Size(400, 20)
    $lbl.Font = $fontLabelBold
    $tabImpostazioni.Controls.Add($lbl)
    
    $txtBox.Text = $defaultPath
    $txtBox.Location = New-Object System.Drawing.Point(20, ($y + 25))
    $txtBox.Size = New-Object System.Drawing.Size(510, 25)
    $tabImpostazioni.Controls.Add($txtBox)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Sfoglia..."
    $btn.Location = New-Object System.Drawing.Point(540, ($y + 24))
    $btn.Size = New-Object System.Drawing.Size(80, 27)
    $tabImpostazioni.Controls.Add($btn)
    
    $btn.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "File Audio (*.wav)|*.wav|Tutti i file (*.*)|*.*"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtBox.Text = $dialog.FileName
        }
    })
}

Crea-RigaAudio "Suono Sgranchisci Gambe (Timer 45m):" $script:txtGambe $script:audioGambe 30
Crea-RigaAudio "Suono Sveglia Uscita Lavoro:" $script:txtSveglia $script:audioSveglia 100
Crea-RigaAudio "Suono Fine Focus Pomodoro (Inizio Pausa):" $script:txtPomoFine $script:audioPomoFine 170
Crea-RigaAudio "Suono Fine Pausa Pomodoro (Ritorno Focus):" $script:txtPomoPausa $script:audioPomoPausa 240

$btnSaveAudio = New-Object System.Windows.Forms.Button
$btnSaveAudio.Text = "💾 Salva Impostazioni Audio"
$btnSaveAudio.Location = New-Object System.Drawing.Point(20, 320)
$btnSaveAudio.Size = New-Object System.Drawing.Size(250, 40)
$btnSaveAudio.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnSaveAudio.ForeColor = [System.Drawing.Color]::White
$btnSaveAudio.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabImpostazioni.Controls.Add($btnSaveAudio)

$btnSaveAudio.Add_Click({
    # Ora andiamo a leggere le proprietà dal riferimento script sicuro
    $script:audioGambe = $script:txtGambe.Text
    $script:audioSveglia = $script:txtSveglia.Text
    $script:audioPomoFine = $script:txtPomoFine.Text
    $script:audioPomoPausa = $script:txtPomoPausa.Text
    
    Save-AudioSettings
    [System.Windows.Forms.MessageBox]::Show("Impostazioni audio salvate!", "Ralph-o-Clock", 0, 64)
})

# --- 4. Setup Tab Diario Agenda ---
$script:diarioCsvPath = Join-Path $cartellaScript "dati\diario_agenda.csv"
$script:diarioNotes = @{}

function Load-Diario {
    if (Test-Path $script:diarioCsvPath) {
        $righe = Import-Csv $script:diarioCsvPath -Delimiter ";" -Encoding UTF8
        foreach ($r in $righe) {
            if ($null -ne $r.Data) { $script:diarioNotes[$r.Data] = $r.Note }
        }
    }
}
function Save-Diario {
    $lista = New-Object System.Collections.Generic.List[PSObject]
    foreach ($key in $script:diarioNotes.Keys) {
        $lista.Add([PSCustomObject]@{ Data = $key; Note = $script:diarioNotes[$key] })
    }
    $lista | Export-Csv -Path $script:diarioCsvPath -NoTypeInformation -Delimiter ";" -Encoding UTF8
}

$calDiario = New-Object System.Windows.Forms.MonthCalendar
$calDiario.Location = New-Object System.Drawing.Point(20, 20)
$tabDiario.Controls.Add($calDiario)

$lblDiarioTitle = New-Object System.Windows.Forms.Label
$lblDiarioTitle.Text = "Note dell'agenda per il giorno selezionato:"
$lblDiarioTitle.Font = $fontLabelBold
$lblDiarioTitle.Location = New-Object System.Drawing.Point(260, 20)
$lblDiarioTitle.Size = New-Object System.Drawing.Size(360, 20)
$tabDiario.Controls.Add($lblDiarioTitle)

$txtDiarioNote = New-Object System.Windows.Forms.TextBox
$txtDiarioNote.Multiline = $true
$txtDiarioNote.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtDiarioNote.Location = New-Object System.Drawing.Point(260, 45)
$txtDiarioNote.Size = New-Object System.Drawing.Size(360, 400)
$txtDiarioNote.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tabDiario.Controls.Add($txtDiarioNote)

$btnSaveDiario = New-Object System.Windows.Forms.Button
$btnSaveDiario.Text = "💾 Salva Pagina Diario"
$btnSaveDiario.Location = New-Object System.Drawing.Point(260, 460)
$btnSaveDiario.Size = New-Object System.Drawing.Size(180, 35)
$btnSaveDiario.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnSaveDiario.ForeColor = [System.Drawing.Color]::White
$btnSaveDiario.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabDiario.Controls.Add($btnSaveDiario)

$chkAutosave = New-Object System.Windows.Forms.CheckBox
$chkAutosave.Text = "🔄 Autosalvataggio"
$chkAutosave.Location = New-Object System.Drawing.Point(455, 465)
$chkAutosave.Size = New-Object System.Drawing.Size(160, 25)
$chkAutosave.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$chkAutosave.Checked = $false
$tabDiario.Controls.Add($chkAutosave)

Load-Diario
$oggiStr = [DateTime]::Now.ToString("yyyy-MM-dd")
if ($script:diarioNotes.ContainsKey($oggiStr)) { $txtDiarioNote.Text = $script:diarioNotes[$oggiStr] }

$calDiario.Add_DateSelected({
    $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
    if ($script:diarioNotes.ContainsKey($dataSel)) {
        $txtDiarioNote.Text = $script:diarioNotes[$dataSel]
    } else {
        $txtDiarioNote.Text = ""
    }
})

$btnSaveDiario.Add_Click({
    $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
    $script:diarioNotes[$dataSel] = $txtDiarioNote.Text
    Save-Diario
    [System.Windows.Forms.MessageBox]::Show("Nota salvata per il giorno $dataSel!", "Diario Agenda", 0, 64)
})

$txtDiarioNote.Add_TextChanged({
    if ($chkAutosave.Checked -and $txtDiarioNote.Focused) {
        $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
        $script:diarioNotes[$dataSel] = $txtDiarioNote.Text
        Save-Diario
    }
})

# --- 5. Setup Interfaccia Tab Pomodoro e CSV ---
$script:pomoFocusTime = 25 * 60
$script:pomoBreakTime = 5 * 60
$script:pomoSeconds = $script:pomoFocusTime
$script:pomoState = "IDLE"
$pomoIconPath = Join-Path $cartellaScript "img\pomodoro.ico"
$script:pomoCsvPath = Join-Path $cartellaScript "dati\pomodoro_tasks.csv"
$script:templatePath = Join-Path $cartellaScript "dati\pomodoro_templates.csv"
$script:activePomoRow = $null

$lblPomoTime = New-Object System.Windows.Forms.Label
$lblPomoTime.Text = "25:00"
$lblPomoTime.Font = New-Object System.Drawing.Font("Segoe UI", 48, [System.Drawing.FontStyle]::Bold)
$lblPomoTime.Location = New-Object System.Drawing.Point(20, 20)
$lblPomoTime.Size = New-Object System.Drawing.Size(200, 80)
$tabPomodoro.Controls.Add($lblPomoTime)

$lblPomoStatus = New-Object System.Windows.Forms.Label
$lblPomoStatus.Text = "Pronto per il Focus"
$lblPomoStatus.Font = $fontTitle
$lblPomoStatus.Location = New-Object System.Drawing.Point(230, 45)
$lblPomoStatus.Size = New-Object System.Drawing.Size(400, 30)
$tabPomodoro.Controls.Add($lblPomoStatus)

$lblStimaFine = New-Object System.Windows.Forms.Label
$lblStimaFine.Text = "Stima Fine Lavori: --:--"
$lblStimaFine.Font = $fontLabelBold
$lblStimaFine.Location = New-Object System.Drawing.Point(20, 110)
$lblStimaFine.Size = New-Object System.Drawing.Size(300, 20)
$tabPomodoro.Controls.Add($lblStimaFine)

$btnDeleteTask = New-Object System.Windows.Forms.Button
$btnDeleteTask.Text = "🗑 Elimina Task"
$btnDeleteTask.Location = New-Object System.Drawing.Point(500, 105)
$btnDeleteTask.Size = New-Object System.Drawing.Size(120, 25)
$tabPomodoro.Controls.Add($btnDeleteTask)

$dgvTasks = New-Object System.Windows.Forms.DataGridView
$dgvTasks.Location = New-Object System.Drawing.Point(20, 140)
$dgvTasks.Size = New-Object System.Drawing.Size(600, 200)
$dgvTasks.AllowUserToAddRows = $true
$dgvTasks.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$tabPomodoro.Controls.Add($dgvTasks)

$dgvTasks.Columns.Add("TaskName", "Nome Attività") | Out-Null
$dgvTasks.Columns.Add("EstPomo", "Stimati") | Out-Null
$dgvTasks.Columns.Add("DonePomo", "Fatti") | Out-Null
$dgvTasks.Columns.Add("RottenPomo", "Marci") | Out-Null
$dgvTasks.Columns.Add("Note", "Note") | Out-Null

$btnStartPomo = New-Object System.Windows.Forms.Button
$btnStartPomo.Text = "▶ Avvia Focus"
$btnStartPomo.Location = New-Object System.Drawing.Point(20, 355)
$btnStartPomo.Size = New-Object System.Drawing.Size(110, 40)
$btnStartPomo.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnStartPomo.ForeColor = [System.Drawing.Color]::White
$btnStartPomo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabPomodoro.Controls.Add($btnStartPomo)

$btnBreak = New-Object System.Windows.Forms.Button
$btnBreak.Text = "☕ Pausa"
$btnBreak.Location = New-Object System.Drawing.Point(135, 355)
$btnBreak.Size = New-Object System.Drawing.Size(100, 40)
$btnBreak.BackColor = [System.Drawing.Color]::DarkSeaGreen
$btnBreak.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabPomodoro.Controls.Add($btnBreak)

$btnStopPomo = New-Object System.Windows.Forms.Button
$btnStopPomo.Text = "🛑 Ferma (Marcio)"
$btnStopPomo.Location = New-Object System.Drawing.Point(240, 355)
$btnStopPomo.Size = New-Object System.Drawing.Size(120, 40)
$btnStopPomo.BackColor = [System.Drawing.Color]::IndianRed
$btnStopPomo.ForeColor = [System.Drawing.Color]::White
$btnStopPomo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabPomodoro.Controls.Add($btnStopPomo)

$lblTemplateTitle = New-Object System.Windows.Forms.Label
$lblTemplateTitle.Text = "Template:"
$lblTemplateTitle.Location = New-Object System.Drawing.Point(20, 415)
$lblTemplateTitle.Size = New-Object System.Drawing.Size(60, 20)
$tabPomodoro.Controls.Add($lblTemplateTitle)

$cbTemplates = New-Object System.Windows.Forms.ComboBox
$cbTemplates.Location = New-Object System.Drawing.Point(80, 412)
$cbTemplates.Size = New-Object System.Drawing.Size(160, 25)
$tabPomodoro.Controls.Add($cbTemplates)

$lblNumPomo = New-Object System.Windows.Forms.Label
$lblNumPomo.Text = "Pomo:"
$lblNumPomo.Location = New-Object System.Drawing.Point(245, 415)
$lblNumPomo.Size = New-Object System.Drawing.Size(40, 20)
$tabPomodoro.Controls.Add($lblNumPomo)

$numPomoTemplate = New-Object System.Windows.Forms.NumericUpDown
$numPomoTemplate.Location = New-Object System.Drawing.Point(285, 412)
$numPomoTemplate.Size = New-Object System.Drawing.Size(50, 25)
$numPomoTemplate.Minimum = 1
$numPomoTemplate.Maximum = 20
$numPomoTemplate.Value = 1
$tabPomodoro.Controls.Add($numPomoTemplate)

$btnApplyTemplate = New-Object System.Windows.Forms.Button
$btnApplyTemplate.Text = "➕ Applica"
$btnApplyTemplate.Location = New-Object System.Drawing.Point(345, 410)
$btnApplyTemplate.Size = New-Object System.Drawing.Size(85, 28)
$tabPomodoro.Controls.Add($btnApplyTemplate)

$btnSaveTemplate = New-Object System.Windows.Forms.Button
$btnSaveTemplate.Text = "💾 Salva"
$btnSaveTemplate.Location = New-Object System.Drawing.Point(435, 410)
$btnSaveTemplate.Size = New-Object System.Drawing.Size(80, 28)
$tabPomodoro.Controls.Add($btnSaveTemplate)

$btnDelTemplate = New-Object System.Windows.Forms.Button
$btnDelTemplate.Text = "🗑 Elimina"
$btnDelTemplate.Location = New-Object System.Drawing.Point(520, 410)
$btnDelTemplate.Size = New-Object System.Drawing.Size(80, 28)
$tabPomodoro.Controls.Add($btnDelTemplate)

# --- Logica di Caricamento Template Strutturati ---
$script:listaTemplate = @()
if (-not (Test-Path $script:templatePath)) {
    @"
TemplateName;EstPomo
Analisi di Materialità;3
Riunione Interoperabilità;2
Sviluppo Codice;4
Review Email;1
"@ | Set-Content -Path $script:templatePath -Encoding UTF8
}
$script:listaTemplate = Import-Csv $script:templatePath -Delimiter ";" -Encoding UTF8
foreach ($t in $script:listaTemplate) { $cbTemplates.Items.Add($t.TemplateName) | Out-Null }

$cbTemplates.Add_SelectedIndexChanged({
    $selText = $cbTemplates.Text
    $match = $script:listaTemplate | Where-Object { $_.TemplateName -eq $selText }
    if ($null -ne $match) {
        $val = 1
        [int]::TryParse($match.EstPomo, [ref]$val) | Out-Null
        $numPomoTemplate.Value = $val
    }
})

# --- 6. Logica Core Pomodoro ed Evidenziazione ---
function Save-PomoTasks {
    $lista = New-Object System.Collections.Generic.List[PSObject]
    foreach ($row in $dgvTasks.Rows) {
        if (-not $row.IsNewRow) {
            $lista.Add([PSCustomObject]@{
                TaskName = $row.Cells["TaskName"].Value
                EstPomo = $row.Cells["EstPomo"].Value
                DonePomo = $row.Cells["DonePomo"].Value
                RottenPomo = $row.Cells["RottenPomo"].Value
                Note = $row.Cells["Note"].Value
            })
        }
    }
    $lista | Export-Csv -Path $script:pomoCsvPath -NoTypeInformation -Delimiter ";" -Encoding UTF8
}

function Load-PomoTasks {
    if (Test-Path $script:pomoCsvPath) {
        $pomoTasks = Import-Csv $script:pomoCsvPath -Delimiter ";" -Encoding UTF8
        foreach ($t in $pomoTasks) {
            $dgvTasks.Rows.Add($t.TaskName, $t.EstPomo, $t.DonePomo, $t.RottenPomo, $t.Note) | Out-Null
        }
    }
}

function Update-EstimateFinish {
    $totPomoRimasti = 0
    foreach ($row in $dgvTasks.Rows) {
        if ($row.IsNewRow) { continue }
        $est = 0; $done = 0
        [int]::TryParse($row.Cells["EstPomo"].Value, [ref]$est) | Out-Null
        [int]::TryParse($row.Cells["DonePomo"].Value, [ref]$done) | Out-Null
        
        if ($script:activePomoRow -and $row -eq $script:activePomoRow) {
            $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
        } elseif ($done -gt $est -and $est -gt 0) {
            $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
        } else {
            $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
        }
        if ($est -gt $done) { $totPomoRimasti += ($est - $done) }
    }
    
    $minutiTotali = $totPomoRimasti * 30
    if ($minutiTotali -gt 0) {
        $orarioFine = [DateTime]::Now.AddMinutes($minutiTotali)
        $lblStimaFine.Text = "Stima Fine Lavori: " + $orarioFine.ToString("HH:mm")
    } else {
        $lblStimaFine.Text = "Stima Fine Lavori: --:--"
    }
    Save-PomoTasks
}

Load-PomoTasks
Update-EstimateFinish

$dgvTasks.Add_CellValueChanged({ Update-EstimateFinish })

$btnDeleteTask.Add_Click({
    if ($dgvTasks.CurrentRow -ne $null -and -not $dgvTasks.CurrentRow.IsNewRow) {
        if ($script:activePomoRow -eq $dgvTasks.CurrentRow) { $script:activePomoRow = $null }
        $dgvTasks.Rows.Remove($dgvTasks.CurrentRow)
        Update-EstimateFinish
    }
})

$pomoTimer = New-Object System.Windows.Forms.Timer
$pomoTimer.Interval = 1000

$pomoTimer.Add_Tick({
    if ($script:pomoSeconds -gt 0) {
        $script:pomoSeconds--
        $min = [int][math]::Floor($script:pomoSeconds / 60)
        $sec = [int]($script:pomoSeconds % 60)
        $timeStr = "{0:D2}:{1:D2}" -f $min, $sec
        $lblPomoTime.Text = $timeStr
        
        $tipo = if($script:pomoState -eq "FOCUS") { "Focus" } else { "Pausa" }
        $sysTrayIcon.Text = "$tipo in corso... $timeStr rimanenti"
    } else {
        $pomoTimer.Stop()
        
        if ($script:pomoState -eq "FOCUS") {
            Play-PomoFineSound 
            if ($script:activePomoRow -ne $null) {
                $done = 0
                [int]::TryParse($script:activePomoRow.Cells["DonePomo"].Value, [ref]$done) | Out-Null
                $script:activePomoRow.Cells["DonePomo"].Value = ($done + 1).ToString()
                $script:activePomoRow = $null
            }
            $script:pomoState = "BREAK"
            $script:pomoSeconds = $script:pomoBreakTime
            $lblPomoTime.Text = "05:00"
            $lblPomoStatus.Text = "Pausa - Ralph ti consiglia di sgranchirti!"
            if (Test-Path $iconPath) { $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPath) }
            
            Update-EstimateFinish
            [System.Windows.Forms.MessageBox]::Show("Pomodoro completato! Fai 5 minuti di pausa.", "Ralph-o-Clock", 0, 64)
            $pomoTimer.Start()
        } elseif ($script:pomoState -eq "BREAK") {
            Play-PomoPausaSound 
            $script:pomoState = "IDLE"
            $lblPomoStatus.Text = "Pronto per il prossimo task"
            $sysTrayIcon.Text = "Ralph-o-Clock"
            Update-EstimateFinish
            [System.Windows.Forms.MessageBox]::Show("Pausa finita! Seleziona un nuovo task.", "Ralph-o-Clock", 0, 64)
        }
    }
})

$btnStartPomo.Add_Click({
    if ($script:pomoState -eq "IDLE" -or $script:pomoState -eq "BREAK") {
        if ($dgvTasks.CurrentRow -ne $null -and -not $dgvTasks.CurrentRow.IsNewRow) {
            $script:activePomoRow = $dgvTasks.CurrentRow
            $script:activePomoRow.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
            $lblPomoStatus.Text = "🎯 In Focus su: " + $script:activePomoRow.Cells["TaskName"].Value
        } else {
            $script:activePomoRow = $null
            $lblPomoStatus.Text = "Focus Time: Nessun progetto selezionato!"
        }
        $script:pomoState = "FOCUS"
        $script:pomoSeconds = $script:pomoFocusTime
        if (Test-Path $pomoIconPath) { $sysTrayIcon.Icon = New-Object System.Drawing.Icon($pomoIconPath) }
        Update-EstimateFinish
        $pomoTimer.Start()
    }
})

$btnBreak.Add_Click({
    if ($script:activePomoRow -ne $null) {
        $script:activePomoRow.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
        $script:activePomoRow = $null
    }
    $script:pomoState = "BREAK"
    $script:pomoSeconds = $script:pomoBreakTime
    $lblPomoStatus.Text = "Pausa Forzata"
    if (Test-Path $iconPath) { $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPath) }
    Update-EstimateFinish
    $pomoTimer.Start()
})

$btnStopPomo.Add_Click({
    if ($script:pomoState -eq "FOCUS") {
        $pomoTimer.Stop()
        if ($script:activePomoRow -ne $null) {
            $marci = 0
            [int]::TryParse($script:activePomoRow.Cells["RottenPomo"].Value, [ref]$marci) | Out-Null
            $script:activePomoRow.Cells["RottenPomo"].Value = ($marci + 1).ToString()
            $script:activePomoRow.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
            $script:activePomoRow = $null
        }
        $script:pomoState = "IDLE"
        $script:pomoSeconds = $script:pomoFocusTime
        $lblPomoTime.Text = "25:00"
        $lblPomoStatus.Text = "Focus Interrotto (Pomodoro Marcio registrato)"
        $sysTrayIcon.Text = "Ralph-o-Clock"
        if (Test-Path $iconPath) { $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPath) }
        Update-EstimateFinish
    }
})

# --- Azioni Gestione Template Sincronizzate ---
$btnApplyTemplate.Add_Click({
    $testo = $cbTemplates.Text.Trim()
    $pomoVal = [int]$numPomoTemplate.Value
    if ($testo -ne "") {
        $dgvTasks.Rows.Add($testo, $pomoVal.ToString(), "0", "0", "") | Out-Null
        Update-EstimateFinish
    }
})

$btnSaveTemplate.Add_Click({
    $testo = $cbTemplates.Text.Trim()
    $pomoVal = [int]$numPomoTemplate.Value
    if ($testo -ne "") {
        $esiste = $script:listaTemplate | Where-Object { $_.TemplateName -eq $testo }
        if ($null -eq $esiste) { $cbTemplates.Items.Add($testo) | Out-Null }
        
        $script:listaTemplate = $script:listaTemplate | Where-Object { $_.TemplateName -ne $testo }
        $script:listaTemplate += [PSCustomObject]@{ TemplateName = $testo; EstPomo = $pomoVal.ToString() }
        $script:listaTemplate | Export-Csv -Path $script:templatePath -NoTypeInformation -Delimiter ";" -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Template salvato con successo!", "Ralph-o-Clock", 0, 64)
    }
})

$btnDelTemplate.Add_Click({
    if ($cbTemplates.Text -ne "") {
        $testo = $cbTemplates.Text
        $cbTemplates.Items.Remove($testo)
        $cbTemplates.Text = ""
        
        $script:listaTemplate = $script:listaTemplate | Where-Object { $_.TemplateName -ne $testo }
        $script:listaTemplate | Export-Csv -Path $script:templatePath -NoTypeInformation -Delimiter ";" -Encoding UTF8
        $numPomoTemplate.Value = 1
        [System.Windows.Forms.MessageBox]::Show("Template eliminato.", "Ralph-o-Clock", 0, 64)
    }
})
# =========================================================================
# FINE INTEGRAZIONE POMODORO E IMPOSTAZIONI
# =========================================================================

$btnSupporto.Add_Click({
    [System.Diagnostics.Process]::Start("mailto:danilo.iannello@inps.it?subject=Richiesta%20Supporto%20-%20Tool%20Orari")
})

# --- Logica Pulsante Elabora Dati ---
$btnCalcola.Add_Click({
    Correggi-FormatoOrario $txtEntrata
    Correggi-FormatoOrario $txtOre
    Correggi-FormatoOrario $txtInizioPausa
    Correggi-FormatoOrario $txtFinePausa
    Correggi-FormatoOrario $txtUscitaEff

    $rtbRisultato.Clear()
    $btnSalvaRegistro.Enabled = $false
    $btnSalvaRegistro.BackColor = [System.Drawing.Color]::DarkGray
    if ($alarmTimer.Enabled -eq $false) { $btnSveglia.Enabled = $false; $btnSveglia.BackColor = [System.Drawing.Color]::DarkGray }
    
    try {
        $oraEntrataInizians = [TimeSpan]::Parse($txtEntrata.Text)
        $oreLavoroObbligatorie = [TimeSpan]::Parse($txtOre.Text)
        $inizioPausa = [TimeSpan]::Parse($txtInizioPausa.Text)
        $finePausa = [TimeSpan]::Parse($txtFinePausa.Text)
        
        $sogliaMinEntrata = [TimeSpan]::Parse("07:30")
        $sogliaMaxEntrata = [TimeSpan]::Parse("11:06")
        $giornataMinima = [TimeSpan]::Parse("03:36")
        $sogliaTicket = [TimeSpan]::Parse("06:30")
        
        if ($oraEntrataInizians -gt $sogliaMaxEntrata) {
            Append-ColoredText -rtb $rtbRisultato -text "ATTENZIONE: Ingresso oltre il limite (11:06).`n" -color ([System.Drawing.Color]::Red) -bold $true
        }

        $oraEntrataEffettiva = $oraEntrataInizians
        if ($oraEntrataInizians -lt $sogliaMinEntrata) {
            $oraEntrataEffettiva = $sogliaMinEntrata
            Append-ColoredText -rtb $rtbRisultato -text "Nota: Conteggio fatto partire dalle 07:30.`n" -color ([System.Drawing.Color]::DarkOrange)
        }

        $durataPausa = $finePausa - $inizioPausa
        if ($inizioPausa -lt "12:30" -or $finePausa -gt "15:00" -or $inizioPausa -ge $finePausa) {
            Append-ColoredText -rtb $rtbRisultato -text "ERRORE: Pausa fuori fascia 12:30 - 15:00.`n" -color ([System.Drawing.Color]::Red) -bold $true
            return
        }

        if ($durataPausa.TotalMinutes -lt 30) {
            Append-ColoredText -rtb $rtbRisultato -text "Nota: Applicati 30 min d'ufficio per pausa pranzo.`n" -color ([System.Drawing.Color]::DarkOrange)
            $durataPausa = [TimeSpan]::FromMinutes(30)
        }

        $orarioUscitaTeorico = $oraEntrataEffettiva + $oreLavoroObbligatorie + $durataPausa


        if (-not [string]::IsNullOrWhiteSpace($txtUscitaEff.Text)) {
            # Se il campo Uscita Effettiva � compilato, la sveglia prender� quell'orario
            $script:orarioUscitaSveglia = [TimeSpan]::Parse($txtUscitaEff.Text)
        } else {
            # Altrimenti, se il campo � vuoto, user� l'uscita teorica standard
            $script:orarioUscitaSveglia = $orarioUscitaTeorico
        }


        if ($alarmTimer.Enabled -eq $false) { $btnSveglia.Enabled = $true; $btnSveglia.BackColor = [System.Drawing.Color]::FromArgb(22, 101, 52) }

        Append-ColoredText -rtb $rtbRisultato -text "`nUscita Teorica Standard: " -color ([System.Drawing.Color]::Black) -bold $true
        Append-ColoredText -rtb $rtbRisultato -text "$($orarioUscitaTeorico.ToString("hh\:mm"))`n" -color ([System.Drawing.Color]::Blue) -bold $true
        # MOSTRA USCITA PER BUONO PASTO SE COMPILATA SOLO L'ENTRATA
        if ([string]::IsNullOrWhiteSpace($txtUscitaEff.Text)) {
            $uscitaBuonoPasto = $oraEntrataEffettiva + [TimeSpan]::FromMinutes(390) # 6 ore e 30 minuti
            Append-ColoredText -rtb $rtbRisultato -text "Uscita per Buono Pasto (6h 30m): " -color ([System.Drawing.Color]::Black) -bold $true
            Append-ColoredText -rtb $rtbRisultato -text "$($uscitaBuonoPasto.ToString("hh\:mm"))`n" -color ([System.Drawing.Color]::ForestGreen) -bold $true
        }

        $script:ultimoConsuntivo = [PSCustomObject]@{
            Data         = $dtpData.Value.ToString("dd/MM/yyyy")
            Entrata      = $txtEntrata.Text
            Pausa        = $durataPausa.TotalMinutes
            Uscita       = "N/D"
            Effettivo    = "N/D"
            Flessibilita = "N/D"
            Ticket       = "NO"
            Umore        = $cbUmore.Text
            Note         = $txtNote.Text
        }

        if (-not [string]::IsNullOrWhiteSpace($txtUscitaEff.Text)) {
            $oraUscitaEffettiva = [TimeSpan]::Parse($txtUscitaEff.Text)
            $oreLavorateEffettive = ($oraUscitaEffettiva - $oraEntrataEffettiva) - $durataPausa
            
            $script:ultimoConsuntivo.Uscita = $txtUscitaEff.Text
            $script:ultimoConsuntivo.Effettivo = $oreLavorateEffettive.ToString("hh\:mm")
            
            Append-ColoredText -rtb $rtbRisultato -text "Tempo lavorato effettivo: $($oreLavorateEffettive.ToString("hh\:mm"))`n" -color ([System.Drawing.Color]::Black)
            
            if ($oreLavorateEffettive -lt $giornataMinima) {
                Append-ColoredText -rtb $rtbRisultato -text "ALLERTA: Giornata minima non raggiunta!`n" -color ([System.Drawing.Color]::Red) -bold $true
            }
            
            if ($oreLavorateEffettive -ge $sogliaTicket) {
                $script:ultimoConsuntivo.Ticket = "SI"
                Append-ColoredText -rtb $rtbRisultato -text "Ticket Pranzo: MATURATO [SI]`n" -color ([System.Drawing.Color]::Green) -bold $true
            } else {
                Append-ColoredText -rtb $rtbRisultato -text "Ticket Pranzo: NON MATURATO [NO]`n" -color ([System.Drawing.Color]::Gray)
            }
            
            $differenza = $oreLavorateEffettive - $oreLavoroObbligatorie
            if ($differenza.TotalMinutes -gt 0) {
                $txtFles = if ($differenza.TotalMinutes -gt 120) { "+02:00 (Tagliata)" } else { "+" + $differenza.ToString("hh\:mm") }
                $script:ultimoConsuntivo.Flessibilita = $txtFles
                Append-ColoredText -rtb $rtbRisultato -text "Flessibilita': $txtFles`n" -color ([System.Drawing.Color]::FromArgb(22, 101, 52)) -bold $true
            } else {
                $script:ultimoConsuntivo.Flessibilita = "-" + [TimeSpan]::FromMinutes([Math]::Abs($differenza.TotalMinutes)).ToString("hh\:mm")
                Append-ColoredText -rtb $rtbRisultato -text "Flessibilita' in debito: $($script:ultimoConsuntivo.Flessibilita)`n" -color ([System.Drawing.Color]::Red) -bold $true
            }
        }
        
        $btnSalvaRegistro.Enabled = $true
        $btnSalvaRegistro.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
        
    } catch {
        Append-ColoredText -rtb $rtbRisultato -text "ERRORE: Controlla la correttezza dei formati inseriti." -color ([System.Drawing.Color]::Red) -bold $true
    }
})

$btnSalvaRegistro.Add_Click({
    if ($script:ultimoConsuntivo -ne $null) {
        $dataRicerca = $script:ultimoConsuntivo.Data
        $rigaEsistente = $null
        
        foreach ($row in $dt.Rows) {
            if ($row["Data"] -eq $dataRicerca) {
                $rigaEsistente = $row
                break
            }
        }
        
        if ($rigaEsistente -ne $null) {
            $rigaEsistente["Entrata"] = $script:ultimoConsuntivo.Entrata
            $rigaEsistente["Pausa (Min)"] = $script:ultimoConsuntivo.Pausa
            $rigaEsistente["Uscita"] = $script:ultimoConsuntivo.Uscita
            $rigaEsistente["Effettivo"] = $script:ultimoConsuntivo.Effettivo
            $rigaEsistente["Flessibilita"] = $script:ultimoConsuntivo.Flessibilita
            $rigaEsistente["Ticket"] = $script:ultimoConsuntivo.Ticket
            $rigaEsistente["Umore"] = $script:ultimoConsuntivo.Umore
            $rigaEsistente["Note"] = $script:ultimoConsuntivo.Note
        } else {
            $row = $dt.NewRow()
            $row["Data"] = $script:ultimoConsuntivo.Data
            $row["Entrata"] = $script:ultimoConsuntivo.Entrata
            $row["Pausa (Min)"] = $script:ultimoConsuntivo.Pausa
            $row["Uscita"] = $script:ultimoConsuntivo.Uscita
            $row["Effettivo"] = $script:ultimoConsuntivo.Effettivo
            $row["Flessibilita"] = $script:ultimoConsuntivo.Flessibilita
            $row["Ticket"] = $script:ultimoConsuntivo.Ticket
            $row["Umore"] = $script:ultimoConsuntivo.Umore
            $row["Note"] = $script:ultimoConsuntivo.Note
            $dt.Rows.Add($row)
        }
        
        Salva-TabellaSuCSV
        $btnSalvaRegistro.Enabled = $false
        $btnSalvaRegistro.BackColor = [System.Drawing.Color]::DarkGray
    }
})

$btnUpdateTabella.Add_Click({
    Salva-TabellaSuCSV
    [System.Windows.Forms.MessageBox]::Show("Modifiche salvate con successo.", "Aggiornamento", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnEliminaRiga.Add_Click({
    if ($dgv.SelectedRows.Count -gt 0) {
        $conferma = [System.Windows.Forms.MessageBox]::Show("Eliminare la riga selezionata?", "Conferma", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($conferma -eq [System.Windows.Forms.DialogResult]::Yes) {
            foreach ($row in $dgv.SelectedRows) { $dgv.Rows.Remove($row) }
            Salva-TabellaSuCSV
        }
    }
})

$btnSvuotaDB.Add_Click({
    $conferma = [System.Windows.Forms.MessageBox]::Show("ATTENZIONE! Vuoi davvero ELIMINARE TUTTI I DATI in modo permanente?", "Conferma Eliminazione Globale", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($conferma -eq [System.Windows.Forms.DialogResult]::Yes) {
        $dt.Rows.Clear()
        if (Test-Path $script:csvPath) { Remove-Item $script:csvPath -Force }
        Calcola-BilancioGlobale
        [System.Windows.Forms.MessageBox]::Show("Database svuotato correttamente.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

# =========================================================================
# GESTIONE SVEGLIA E SYSTEM TRAY (FIX DEFINITIVO APPLICAZIONE)
# =========================================================================

# 1. Doppio clic per riaprire
$sysTrayIcon.Add_DoubleClick({
    $form.Show()
    $form.WindowState = "Normal"
    
    # Se la sveglia principale NON � attiva, nasconde di nuovo l'icona per tenere pulita la taskbar
    if ($btnSveglia.Enabled -eq $true) {
        $sysTrayIcon.Visible = $false
    }
})

# 2. Pulsante Sveglia
$btnSveglia.Add_Click({
    if ($script:orarioUscitaSveglia -eq $null -or $script:orarioUscitaSveglia -eq "") {
        [System.Windows.Forms.MessageBox]::Show("Devi prima cliccare 'Elabora Dati' per calcolare l'orario di uscita!", "Attenzione", 0, 48)
        return
    }

    # -- NUOVO: CONTROLLO ORARIO GIA' PASSATO --
    $targetTime = $script:orarioUscitaSveglia
    if ($targetTime.GetType().Name -eq "String" -or $targetTime.GetType().Name -eq "DateTime") {
        $targetTime = [TimeSpan]::Parse($targetTime.ToString().Split(' ')[-1])
    }
    
    $oraAttuale = [DateTime]::Now.TimeOfDay
    if (($targetTime - $oraAttuale).TotalSeconds -le 0) {
        [System.Windows.Forms.MessageBox]::Show("L'orario impostato per la sveglia � gi� passato! Inserisci un orario futuro.", "Errore Sveglia", 0, 16)
        return
    }
    # ------------------------------------------

    $sysTrayIcon.Visible = $true
    $btnStopSveglia.Enabled = $true
    $btnStopSveglia.BackColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
    $btnSveglia.Enabled = $false
    $btnSveglia.BackColor = [System.Drawing.Color]::DarkGray
    
    $form.WindowState = "Minimized"
    $form.Hide()
    
    $alarmTimer.Start()
})

# 3. Pulsante Stop Manuale
$btnStopSveglia.Add_Click({
    $alarmTimer.Stop()
    $sysTrayIcon.Visible = $false
    $btnStopSveglia.Enabled = $false
    $btnStopSveglia.BackColor = [System.Drawing.Color]::DarkGray
    $btnSveglia.Enabled = $true
    $btnSveglia.BackColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
    
    $form.Show()
    $form.WindowState = "Normal"
})

# 4. Timer Sveglia
$alarmTimer.Add_Tick({
    try {
        if ($script:orarioUscitaSveglia -eq $null) { return }

        $targetTime = $script:orarioUscitaSveglia
        if ($targetTime.GetType().Name -eq "String" -or $targetTime.GetType().Name -eq "DateTime") {
            $targetTime = [TimeSpan]::Parse($targetTime.ToString().Split(' ')[-1])
        }

        $oraAttuale = [DateTime]::Now.TimeOfDay
        $tempoMancante = $targetTime - $oraAttuale

        $statoAuto = if ($chkAutoStart.Checked) { "Attivo" } else { "Disattivo" }

        if ($tempoMancante.TotalSeconds -gt 0) {
            $sysTrayIcon.Text = "Sveglia: {0:00}:{1:00}`nAutoStart: $statoAuto`nManca: {2:00}:{3:00}:{4:00}" -f $targetTime.Hours, $targetTime.Minutes, [math]::Floor($tempoMancante.TotalHours), $tempoMancante.Minutes, $tempoMancante.Seconds
        }
        else {
            # SVEGLIA!
            $alarmTimer.Stop()
            $sysTrayIcon.Visible = $false
            
            $btnStopSveglia.Enabled = $false
            $btnStopSveglia.BackColor = [System.Drawing.Color]::DarkGray
            $btnSveglia.Enabled = $true
            $btnSveglia.BackColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
            
            $form.Show()
            $form.WindowState = "Normal"
            $form.Activate()
            
            try { Play-AlarmSound } catch { }
            [System.Windows.Forms.MessageBox]::Show("Orario di uscita raggiunto!", "Sveglia di Ralph", 0, 64)
        }
    } catch {
        # Fallback invisibile: se c'� un'esitazione nel calcolo del tempo, ignora e riprova al secondo successivo
    }
})

# Permette di rimandare il programma nel System Tray cliccando Riduci a Icona (_)
$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
        $sysTrayIcon.Visible = $true   # <-- Rende l'icona visibile per evitare di perdere il programma
        $form.Hide()
    }
})

# Esegui i suoni di avvio, se presenti
Play-StartupSound
Carica-CSV

[System.Windows.Forms.Application]::Run($form)

if ($chkAutoStart.Checked) {
    $form.WindowState = "Minimized"
    $form.Hide()
    $sysTrayIcon.Visible = $true
}