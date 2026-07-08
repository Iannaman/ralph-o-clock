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
$usr = $env:USERNAME # Cattura l'utente Windows attuale
$cartellaScript = $env:BATDIR

if ([string]::IsNullOrWhiteSpace($cartellaScript)) { $cartellaScript = [System.IO.Directory]::GetCurrentDirectory() }

# Leggiamo il master_config.txt per capire dove l'utente vuole i dati
$masterConfigPath = Join-Path $cartellaScript "master_config.txt"
if (Test-Path $masterConfigPath) {
    $script:cartellaDati = Get-Content $masterConfigPath
} else {
    $script:cartellaDati = Join-Path $cartellaScript "dati" 
}

if (-not (Test-Path $script:cartellaDati)) {
    New-Item -ItemType Directory -Path $script:cartellaDati | Out-Null
}

# --- ASSEGNAZIONE DINAMICA DEI FILE ---
$fileImpostazioni     = Join-Path $script:cartellaDati "settings_$usr.txt"
$settingsPath         = Join-Path $script:cartellaDati "settings_$usr.txt"
$script:csvPath       = Join-Path $script:cartellaDati "registro_orari_$usr.csv"
$script:pomoCsvPath   = Join-Path $script:cartellaDati "pomodoro_tasks_$usr.csv"
$script:templatePath  = Join-Path $script:cartellaDati "pomodoro_templates_$usr.csv"

$iconPath = Join-Path $cartellaScript "img\ralph.ico"
$imgPath = Join-Path $cartellaScript "img\ralph.png"
$audioPath = Join-Path $cartellaScript "audio\Ralph-bark.wav"
$audioAlarmPath = Join-Path $cartellaScript "audio\let-the-dogs-out.wav"

$settingsPath = Join-Path $cartellaScript "dati\settings_$usr.txt"
$script:datiElaborati = $false

function Save-Settings {
    "$($chkStretch.Checked)|$($txtStretchMin.Text)|$($chkAutoStart.Checked)|$($chkNascondiUmore.Checked)" | Out-File $settingsPath
}

function Load-Settings {
    if (Test-Path $settingsPath) {
        $data = (Get-Content $settingsPath).Split('|')
        if ($data.Length -ge 1) { $chkStretch.Checked = [bool]::Parse($data[0]) }
        if ($data.Length -ge 2) { $txtStretchMin.Text = $data[1] }
        if ($data.Length -ge 3) { $chkAutoStart.Checked = [bool]::Parse($data[2]) }
        if ($data.Length -ge 4) { $chkNascondiUmore.Checked = [bool]::Parse($data[3]) } else { $chkNascondiUmore.Checked = $false }
    }
}

function Applica-VisibilitaUmore {
    $vis = -not $chkNascondiUmore.Checked
    
    $lblUmore.Visible = $vis
    $btnInfoUmore.Visible = $vis
    $cbUmore.Visible = $vis
    
    if ($vis) {
        $lblNote.Location = New-Object System.Drawing.Point(20, 410)
        $txtNote.Location = New-Object System.Drawing.Point(20, 430)
        $txtNote.Size = New-Object System.Drawing.Size(360, 50)
    } else {
        $lblNote.Location = New-Object System.Drawing.Point(20, 355)
        $txtNote.Location = New-Object System.Drawing.Point(20, 375)
        $txtNote.Size = New-Object System.Drawing.Size(360, 105)
    }
    
    if ($null -ne $dgv.Columns["Umore"]) {
        $dgv.Columns["Umore"].Visible = $vis
    }
    
    $lblStatUmore.Visible = $vis
}

function Play-StartupSound {
    if (Test-Path $script:audioGambe) {
        $player = New-Object System.Media.SoundPlayer($script:audioGambe)
        $player.Play()
    }
}
function Play-AlarmSound {
    if (Test-Path $script:audioSveglia) {
        $player = New-Object System.Media.SoundPlayer($script:audioSveglia)
        $player.Play()
    } else { 
        for ($i=0; $i -lt 5; $i++) { [System.Console]::Beep(880, 400); Start-Sleep -Milliseconds 200 } 
    }
}
function Play-PomoFineSound {
    if (Test-Path $script:audioPomoFine) {
        $player = New-Object System.Media.SoundPlayer($script:audioPomoFine)
        $player.Play()
    } else { Play-AlarmSound }
}
function Play-PomoPausaSound {
    if (Test-Path $script:audioPomoPausa) {
        $player = New-Object System.Media.SoundPlayer($script:audioPomoPausa)
        $player.Play()
    } else { Play-StartupSound }
}

$cartellaScript = $env:BATDIR
if ([string]::IsNullOrWhiteSpace($cartellaScript)) { $cartellaScript = [System.IO.Directory]::GetCurrentDirectory() }
$script:csvPath = Join-Path $cartellaScript "dati\registro_orari_$usr.csv"

# --- Configurazione Stile ---
$fontLabel = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$fontLabelBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$bgColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

$script:orarioUscitaSveglia = $null
$script:ultimoConsuntivo = $null
$script:datiElaborati = $false

$azioneRicalcolo = {
    if ($script:datiElaborati) {
        $btnCalcola.PerformClick()
    }
}

# --- Finestra Principale ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Ralph-o-Clock - Registro Orari & Umore - v.3.01" 
$form.Size = New-Object System.Drawing.Size(1100, 830)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $bgColor
$form.KeyPreview = $true

# --- INIZIO BLOCCO ADMIN MODE ---
$btnExitImpersonation = New-Object System.Windows.Forms.Button
$btnExitImpersonation.Text = "Esci Impersonificazione"
$btnExitImpersonation.Location = New-Object System.Drawing.Point(275, 125)
$btnExitImpersonation.Size = New-Object System.Drawing.Size(150, 25)
$btnExitImpersonation.BackColor = [System.Drawing.Color]::IndianRed
$btnExitImpersonation.ForeColor = [System.Drawing.Color]::White
$btnExitImpersonation.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnExitImpersonation.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnExitImpersonation.Visible = $false
$form.Controls.Add($btnExitImpersonation)

$btnExitImpersonation.Add_Click({
    Impersona-Utente -NuovoUtente $env:USERNAME
})

function Impersona-Utente {
    param([string]$NuovoUtente)
    
    $global:usr = $NuovoUtente
    $script:usr = $NuovoUtente
    $usr = $NuovoUtente

    $global:settingsPath         = Join-Path $script:cartellaDati "settings_$NuovoUtente.txt"
    $script:csvPath              = Join-Path $script:cartellaDati "registro_orari_$NuovoUtente.csv"
    $script:pomoCsvPath          = Join-Path $script:cartellaDati "pomodoro_tasks_$NuovoUtente.csv"
    $script:templatePath         = Join-Path $script:cartellaDati "pomodoro_templates_$NuovoUtente.csv"
    $script:diarioCsvPath        = Join-Path $script:cartellaDati "diario_agenda_$NuovoUtente.csv"
    $script:audioSettingsPath    = Join-Path $script:cartellaDati "audio_settings_$NuovoUtente.txt"

    if ($NuovoUtente -ne $env:USERNAME) {
        $form.Text = "Ralph-o-Clock - Impersonificando: $NuovoUtente"
        $btnExitImpersonation.Visible = $true
    } else {
        $form.Text = "Ralph-o-Clock - Registro Orari & Umore - v.3.01"
        $btnExitImpersonation.Visible = $false
    }

    $txtEntrata.Text = ""
    $txtUscitaEff.Text = ""
    $txtNote.Text = ""

    $script:diarioNotes.Clear()
    $script:diarioTags.Clear()
    $dgvTasks.Rows.Clear()
   
    $statoAutosave = $chkAutosave.Checked
    $chkAutosave.Checked = $false

    # Rimuove il filtro di eventuali mesi selezionati prima del caricamento per non sfalsare le statistiche
    $dt.DefaultView.RowFilter = ""

    Load-Settings
    Applica-VisibilitaUmore
    Load-AudioSettings
    Carica-CSV
    Load-Diario
    Load-PomoTasks
    
    Aggiorna-ContatoriDiario 
    
    $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
    if ($script:diarioNotes.ContainsKey($dataSel)) { $txtDiarioNote.Text = $script:diarioNotes[$dataSel] } else { $txtDiarioNote.Text = "" }
    if ($script:diarioTags.ContainsKey($dataSel)) { $cbTag.SelectedItem = $script:diarioTags[$dataSel] } else { $cbTag.SelectedIndex = 0 }
    
    $chkAutosave.Checked = $statoAutosave
    Aggiorna-MatriceColleghi
}

$form.Add_KeyDown({
    if ($_.Control -and $_.Shift -and $_.KeyCode -eq 'A') {
        $adminForm = New-Object System.Windows.Forms.Form
        $adminForm.Text = "Menu Admin"
        $adminForm.Size = New-Object System.Drawing.Size(300, 160)
        $adminForm.StartPosition = "CenterParent"
        
        $cbUtenti = New-Object System.Windows.Forms.ComboBox
        $cbUtenti.Location = New-Object System.Drawing.Point(15, 35)
        $cbUtenti.Size = New-Object System.Drawing.Size(250, 25)
        $cbUtenti.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $adminForm.Controls.Add($cbUtenti)

        $listaFile = Get-ChildItem -Path $script:cartellaDati -Filter "diario_agenda_*.csv"
        foreach ($f in $listaFile) {
            $nome = $f.Name -replace "diario_agenda_", "" -replace "\.csv", ""
            [void]$cbUtenti.Items.Add($nome)
        }

        $btnApplica = New-Object System.Windows.Forms.Button
        $btnApplica.Text = "Impersona"
        $btnApplica.Location = New-Object System.Drawing.Point(15, 75)
        $btnApplica.Add_Click({
            if ($cbUtenti.SelectedItem) {
                Impersona-Utente -NuovoUtente $cbUtenti.SelectedItem
                $adminForm.Close()
            }
        })
        $adminForm.Controls.Add($btnApplica)
        $adminForm.ShowDialog()
    }
})
# --- FINE BLOCCO ADMIN MODE ---

# === INSERIMENTO IMMAGINE RALPH NEL FORM ===
$picRalph = New-Object System.Windows.Forms.PictureBox
$picRalph.Location = New-Object System.Drawing.Point(300, 20) 
$picRalph.Size = New-Object System.Drawing.Size(100, 100)
$picRalph.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage

$pngPath = Join-Path $cartellaScript "img\ralph.png"
if (Test-Path $pngPath) {
    $picRalph.Image = [System.Drawing.Image]::FromFile($pngPath)
}
$form.Controls.Add($picRalph)

# --- LABEL DISPLAY ORARIO E COUNTDOWN ---
$lblOrarioUscita = New-Object System.Windows.Forms.Label
$lblOrarioUscita.Text = "L'orario di uscita = --:--"
$lblOrarioUscita.Location = New-Object System.Drawing.Point(200, 155)
$lblOrarioUscita.Size = New-Object System.Drawing.Size(200, 20)
$lblOrarioUscita.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblOrarioUscita.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($lblOrarioUscita)

$lblCountdown = New-Object System.Windows.Forms.Label
$lblCountdown.Text = ""
$lblCountdown.Location = New-Object System.Drawing.Point(200, 175)
$lblCountdown.Size = New-Object System.Drawing.Size(200, 20)
$lblCountdown.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblCountdown.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblCountdown.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$form.Controls.Add($lblCountdown)

$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 1000
$uiTimer.Add_Tick({
    try {
        if ($null -ne $script:orarioUscitaSveglia) {
            $oraAttuale = [DateTime]::Now.TimeOfDay
            $target = [TimeSpan]::Parse($script:orarioUscitaSveglia.ToString().Split(' ')[-1])
            $tempoMancante = $target - $oraAttuale
            
            if ($tempoMancante.TotalSeconds -gt 0) {
                $lblCountdown.Text = "Mancano {0:hh\:mm\:ss} all'uscita" -f $tempoMancante
            } else {
                $lblCountdown.Text = "È ora di uscire! 🐕"
                $lblCountdown.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
                $uiTimer.Stop()
            }
        }
    } catch {}
})

$sysTrayIcon = New-Object System.Windows.Forms.NotifyIcon
$sysTrayIcon.Text = "Ralph-o-Clock"
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
$txtEntrata.Add_Leave($azioneRicalcolo)
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
$txtOre.Add_Leave($azioneRicalcolo)
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
$txtInizioPausa.Add_Leave($azioneRicalcolo)
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
$txtFinePausa.Add_Leave($azioneRicalcolo)
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
$txtUscitaEff.Add_Leave($azioneRicalcolo)
$form.Controls.Add($txtUscitaEff)

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
            $txtStretchMin.Enabled = $false 
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

$stretchTimer.Add_Tick({
    try { Play-StartupSound } catch {}
})

$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$shortcutPath = [System.IO.Path]::Combine($startupFolder, "Ralph-o-Clock.lnk")

$chkAutoStart = New-Object System.Windows.Forms.CheckBox
$chkAutoStart.Text = "Avvio automatico all'accensione"
$chkAutoStart.Location = New-Object System.Drawing.Point(20, 550)
$chkAutoStart.Size = New-Object System.Drawing.Size(200, 30)
$chkAutoStart.Checked = (Test-Path $shortcutPath)
$form.Controls.Add($chkAutoStart)

$chkAutoStart.Add_CheckedChanged({
    if ($chkAutoStart.Checked) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $env:BATFILE
        $shortcut.WorkingDirectory = $env:BATDIR
        $shortcut.Save()
    } else {
        if (Test-Path $shortcutPath) { Remove-Item $shortcutPath }
    }
    Save-Settings
})

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
    $msg = " Modalita' Cane da Guardia `n`nQuando questa opzione e' attiva, Ralph fa credere al PC che tu sia presente e cosi non va in standby.`n`nRisultato:`n- Schermo sempre acceso.`n- (Disponibile)"
    [System.Windows.Forms.MessageBox]::Show($msg, "Cane da Guardia", 0, 64)
})

$awakeTimer = New-Object System.Windows.Forms.Timer
$awakeTimer.Interval = 59000 

$chkAwake.Add_CheckedChanged({
    $iconPathGuardia = Join-Path $cartellaScript "img\Ralph-cane-guardia.ico"
    $pngPathGuardia = Join-Path $cartellaScript "img\Ralph-cane-guardia.png"
    $pngPathStandard = Join-Path $cartellaScript "img\ralph.png"
    
    if ($chkAwake.Checked) {
        $awakeTimer.Start()
        $sysTrayIcon.Text = "Cane guardia attivo"
        if (Test-Path $iconPathGuardia) { $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPathGuardia) }
        if (Test-Path $pngPathGuardia) { $picRalph.Image = [System.Drawing.Image]::FromFile($pngPathGuardia) }
    } else {
        $awakeTimer.Stop()
        $sysTrayIcon.Text = "Cane guardia disattivo"
        if (Test-Path $iconPath) { $sysTrayIcon.Icon = New-Object System.Drawing.Icon($iconPath) } else { $sysTrayIcon.Icon = [System.Drawing.SystemIcons]::Information }
        if (Test-Path $pngPathStandard) { $picRalph.Image = [System.Drawing.Image]::FromFile($pngPathStandard) }
    }
})

$awakeTimer.Add_Tick({
    try { [System.Windows.Forms.SendKeys]::SendWait("{F15}") } catch {}
})

$rtbRisultato = New-Object System.Windows.Forms.RichTextBox
$rtbRisultato.Location = New-Object System.Drawing.Point(20, 575)  
$rtbRisultato.Size = New-Object System.Drawing.Size(360, 110)      
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
# PANNELLO DESTRO E TABELLE
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

$lblStatUmore = New-Object System.Windows.Forms.Label
$lblStatUmore.Location = New-Object System.Drawing.Point(410, 575)
$lblStatUmore.Size = New-Object System.Drawing.Size(630, 60)
$lblStatUmore.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$lblStatUmore.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblStatUmore.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblStatUmore.BackColor = [System.Drawing.Color]::FromArgb(240, 249, 255) 
$lblStatUmore.Text = "Statistica Umore Mensile: In Calcolo..."
$form.Controls.Add($lblStatUmore)

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
$lblCredits.Location = New-Object System.Drawing.Point(900, 745)
$lblCredits.Size = New-Object System.Drawing.Size(130, 20)
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

[console]::OutputEncoding = [System.Text.Encoding]::UTF8

$cartelleApp = @("audio", "dati", "img")
foreach ($c in $cartelleApp) {
    $dirPath = Join-Path $cartellaScript $c
    if (-not (Test-Path $dirPath)) { New-Item -ItemType Directory -Force -Path $dirPath | Out-Null }
}

$script:audioSettingsPath = Join-Path $cartellaScript "dati\audio_settings_$usr.txt"
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

$script:meseSelezionato = [DateTime]::Now.Month
$script:annoSelezionato = [DateTime]::Now.Year
$script:bottoniMesi = @{}

$tabColleghi = New-Object System.Windows.Forms.TabPage
$tabColleghi.Text = "Colleghi"
$tabColleghi.BackColor = $bgColor
$tabControl.TabPages.Add($tabColleghi)

$panelControlli = New-Object System.Windows.Forms.FlowLayoutPanel
$panelControlli.Dock = [System.Windows.Forms.DockStyle]::Top
$panelControlli.AutoSize = $true
$panelControlli.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$panelControlli.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$panelControlli.WrapContents = $true
$panelControlli.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)
$tabColleghi.Controls.Add($panelControlli)

$nomiMesi = @("Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic")

function Evidenzia-BottoneMese ($meseAttivo) {
    foreach ($chiave in $script:bottoniMesi.Keys) {
        if ($chiave -eq $meseAttivo) {
            $script:bottoniMesi[$chiave].BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
            $script:bottoniMesi[$chiave].ForeColor = [System.Drawing.Color]::White
        } else {
            $script:bottoniMesi[$chiave].BackColor = [System.Drawing.Color]::LightGray
            $script:bottoniMesi[$chiave].ForeColor = [System.Drawing.Color]::Black
        }
    }
}

for ($m = 1; $m -le 12; $m++) {
    $btnMese = New-Object System.Windows.Forms.Button
    $btnMese.Text = $nomiMesi[$m-1]
    $btnMese.Size = New-Object System.Drawing.Size(50, 30)
    $btnMese.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMese.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnMese.Tag = $m
    $btnMese.Margin = New-Object System.Windows.Forms.Padding(2)
    
    $btnMese.Add_Click({
        param($sender, $e)
        $script:meseSelezionato = $sender.Tag
        Evidenzia-BottoneMese $sender.Tag
        Aggiorna-MatriceColleghi
    })
    
    $script:bottoniMesi[$m] = $btnMese
    $panelControlli.Controls.Add($btnMese)
}

$btnTutti = New-Object System.Windows.Forms.Button
$btnTutti.Text = "Tutti"
$btnTutti.Size = New-Object System.Drawing.Size(55, 30)
$btnTutti.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnTutti.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnTutti.Tag = 0
$btnTutti.Margin = New-Object System.Windows.Forms.Padding(2, 2, 20, 2)

$btnTutti.Add_Click({
    param($sender, $e)
    $script:meseSelezionato = 0
    Evidenzia-BottoneMese 0
    Aggiorna-MatriceColleghi
})
$script:bottoniMesi[0] = $btnTutti
$panelControlli.Controls.Add($btnTutti)

$btnAggiornaColleghi = New-Object System.Windows.Forms.Button
$btnAggiornaColleghi.Text = "Aggiorna"
$btnAggiornaColleghi.Size = New-Object System.Drawing.Size(90, 30)
$btnAggiornaColleghi.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnAggiornaColleghi.BackColor = [System.Drawing.Color]::FromArgb(5, 150, 105)
$btnAggiornaColleghi.ForeColor = [System.Drawing.Color]::White
$btnAggiornaColleghi.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnAggiornaColleghi.Margin = New-Object System.Windows.Forms.Padding(5, 2, 2, 2)
$panelControlli.Controls.Add($btnAggiornaColleghi)

$dgvColleghi = New-Object System.Windows.Forms.DataGridView
$dgvColleghi.Dock = [System.Windows.Forms.DockStyle]::Fill
$dgvColleghi.AllowUserToAddRows = $false
$dgvColleghi.AllowUserToDeleteRows = $false
$dgvColleghi.ReadOnly = $true
$dgvColleghi.RowHeadersVisible = $false
$dgvColleghi.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
$dgvColleghi.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$dgvColleghi.AllowUserToResizeColumns = $true
$dgvColleghi.DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$tabColleghi.Controls.Add($dgvColleghi)
$dgvColleghi.BringToFront()

$btnAggiornaColleghi.Add_Click({
    Aggiorna-MatriceColleghi
})

Evidenzia-BottoneMese $script:meseSelezionato

$tabImpostazioni = New-Object System.Windows.Forms.TabPage
$tabImpostazioni.Text = "Impostazioni"
$tabImpostazioni.BackColor = $bgColor
$tabControl.TabPages.Add($tabImpostazioni)

$form.Controls.Add($tabControl)

$controlliDestri = @($lblTitleReg, $flpMesi, $dgv, $lblBilancioMensile, $lblStatUmore, $btnUpdateTabella , $btnEliminaRiga, $btnSvuotaDB)
foreach ($ctrl in $controlliDestri) {
    if ($null -ne $ctrl) {
        $form.Controls.Remove($ctrl)
        $ctrl.Location = New-Object System.Drawing.Point(($ctrl.Location.X - 400), ($ctrl.Location.Y - 15))
        $tabRegistro.Controls.Add($ctrl)
    }
}

function Aggiorna-MatriceColleghi {
    $dgvColleghi.Columns.Clear()
    $dgvColleghi.Rows.Clear()
    
    $anno = $script:annoSelezionato
    $mese = $script:meseSelezionato
    
    $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col.Name = "Collega"
    $col.HeaderText = "Collega"
    $col.Frozen = $true
    $col.Width = 130
    $dgvColleghi.Columns.Add($col) | Out-Null
    
    if ($mese -eq 0) {
        for ($m = 1; $m -le 12; $m++) {
            $giorniNelMese = [DateTime]::DaysInMonth($anno, $m)
            for ($d = 1; $d -le $giorniNelMese; $d++) {
                $colGiorno = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
                $colGiorno.Name = "M$($m)_D$($d)"
                $colGiorno.HeaderText = "$d/$m"
                $colGiorno.Width = 45 
                $dgvColleghi.Columns.Add($colGiorno) | Out-Null
            }
        }
    } else {
        $giorniNelMese = [DateTime]::DaysInMonth($anno, $mese)
        for ($d = 1; $d -le $giorniNelMese; $d++) {
            $colGiorno = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colGiorno.Name = "G$d"
            $colGiorno.HeaderText = "{0:00}" -f $d
            $colGiorno.Width = 45
            $dgvColleghi.Columns.Add($colGiorno) | Out-Null
        }
    }
    
    $coloriTag = @{
        "UFFICIO" = [System.Drawing.Color]::LightGray
        "SWOR"    = [System.Drawing.Color]::LightGreen
        "FERIE"   = [System.Drawing.Color]::LightCoral
	    "exFest"  = [System.Drawing.Color]::DarkSalmon
        "104"     = [System.Drawing.Color]::LightGoldenrodYellow
        "LREM"    = [System.Drawing.Color]::LightSeaGreen
        "ASS"     = [System.Drawing.Color]::MediumPurple
        "FEST"    = [System.Drawing.Color]::LightCoral
    }
    
    $percorso = if ($script:cartellaDati) { $script:cartellaDati } else { ".\dati" }
    if (-Not (Test-Path $percorso)) { return }

    $filesColleghi = Get-ChildItem -Path $percorso -Filter "diario_agenda_*.csv"
    if ($filesColleghi.Count -eq 0) { return }

    foreach ($file in $filesColleghi) {
        $nomeCollega = $file.Name -replace "diario_agenda_", "" -replace "\.csv", ""
        
        $rigaIdx = $dgvColleghi.Rows.Add()
        $riga = $dgvColleghi.Rows[$rigaIdx]
        $riga.Cells["Collega"].Value = $nomeCollega
        
        $datiCollega = Import-Csv -Path $file.FullName -Delimiter ";" -ErrorAction SilentlyContinue
        
        if ($datiCollega) {
            foreach ($record in $datiCollega) {
                $y = 0; $mRecord = 0; $dRecord = 0
                
                if ($record.Data -match "^(\d{4})[-/](\d{2})[-/](\d{2})") {
                    $y = [int]$matches[1]; $mRecord = [int]$matches[2]; $dRecord = [int]$matches[3]
                } elseif ($record.Data -match "^(\d{2})[-/](\d{2})[-/](\d{4})") {
                    $dRecord = [int]$matches[1]; $mRecord = [int]$matches[2]; $y = [int]$matches[3]
                }
                
                if ($y -eq $anno -and $dRecord -gt 0) {
                    $chiaveColonna = ""
                    if ($mese -eq 0) {
                        $chiaveColonna = "M$($mRecord)_D$($dRecord)"
                    } elseif ($mRecord -eq $mese) {
                        $chiaveColonna = "G$dRecord"
                    }
                    
                    if ($chiaveColonna -and $dgvColleghi.Columns.Contains($chiaveColonna)) {
                        $tag = if ($record.Tag) { $record.Tag.ToUpper().Trim() } else { "" }
                        if ($tag -ne "") {
                            $riga.Cells[$chiaveColonna].Value = $tag
                            if ($coloriTag.ContainsKey($tag)) {
                                $riga.Cells[$chiaveColonna].Style.BackColor = $coloriTag[$tag]
                            } else {
                                $riga.Cells[$chiaveColonna].Style.BackColor = [System.Drawing.Color]::WhiteSmoke
                            }
                        }
                    }
                }
            }
        }
    }
}

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
        $dialog.Filter = "File Audio supportati (*.wav)|*.wav|Tutti i file (*.*)|*.*"
        $dialog.Title = "Seleziona un file audio (SOLO formato .WAV)"
        
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtBox.Text = $dialog.FileName
        }
    }.GetNewClosure())
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
    $script:audioGambe = $script:txtGambe.Text
    $script:audioSveglia = $script:txtSveglia.Text
    $script:audioPomoFine = $script:txtPomoFine.Text
    $script:audioPomoPausa = $script:txtPomoPausa.Text
    
    Save-AudioSettings
    [System.Windows.Forms.MessageBox]::Show("Impostazioni audio salvate!", "Ralph-o-Clock", 0, 64)
})

$lblDataDir = New-Object System.Windows.Forms.Label
$lblDataDir.Text = "Cartella salvataggio dati (Registro, Diario, Pomodoro, Impostazioni):"
$lblDataDir.Font = $fontLabelBold
$lblDataDir.Location = New-Object System.Drawing.Point(20, 460) 
$lblDataDir.Size = New-Object System.Drawing.Size(400, 20)
$tabImpostazioni.Controls.Add($lblDataDir)

$txtDataDir = New-Object System.Windows.Forms.TextBox
$txtDataDir.Location = New-Object System.Drawing.Point(20, 485) 
$txtDataDir.Size = New-Object System.Drawing.Size(510, 25)
$txtDataDir.Text = $script:cartellaDati
$txtDataDir.ReadOnly = $true 
$tabImpostazioni.Controls.Add($txtDataDir)

$btnDataDir = New-Object System.Windows.Forms.Button
$btnDataDir.Text = "Sfoglia..."
$btnDataDir.Location = New-Object System.Drawing.Point(540, 485) 
$btnDataDir.Size = New-Object System.Drawing.Size(80, 27)
$tabImpostazioni.Controls.Add($btnDataDir)

$btnDataDir.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Seleziona la cartella principale dove salvare i dati operativi di Ralph-o-Clock"
    $folderBrowser.SelectedPath = $script:cartellaDati
    
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $nuovoPercorso = $folderBrowser.SelectedPath
        
        if ($nuovoPercorso -ne $script:cartellaDati) {
            try {
                if (Test-Path $script:cartellaDati) {
                    Copy-Item -Path "$($script:cartellaDati)\*" -Destination $nuovoPercorso -Recurse -Force -ErrorAction Stop
                }
                
                $script:cartellaDati = $nuovoPercorso
                $script:cartellaDati | Out-File -FilePath $masterConfigPath -Encoding UTF8 -Force
                
                [System.Windows.Forms.MessageBox]::Show("Cartella aggiornata e dati trasferiti con successo!", "Ralph-o-Clock", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Si è verificato un errore durante il trasferimento dei file: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    }
})

# --- NUOVA OPZIONE: NASCONDI UMORE ---
$chkNascondiUmore = New-Object System.Windows.Forms.CheckBox
$chkNascondiUmore.Text = "Nascondi Monitoraggio Umore (Aumenta spazio Note)"
$chkNascondiUmore.Font = $fontLabelBold
$chkNascondiUmore.Location = New-Object System.Drawing.Point(20, 530)
$chkNascondiUmore.Size = New-Object System.Drawing.Size(400, 25)
$tabImpostazioni.Controls.Add($chkNascondiUmore)

$chkNascondiUmore.Add_CheckedChanged({
    Applica-VisibilitaUmore
    Save-Settings
})

# --- Setup Tab Diario Agenda e Statistiche Dinamiche ---
$script:diarioCsvPath = Join-Path $script:cartellaDati "diario_agenda_$usr.csv"
$script:diarioNotes = @{}
$script:diarioTags = @{} 

function Load-Diario {
    if (Test-Path $script:diarioCsvPath) {
        $righe = Import-Csv -Path $script:diarioCsvPath -Delimiter ";" -Encoding UTF8
        foreach ($r in $righe) {
            if ($null -ne $r.Data) {
                $script:diarioNotes[$r.Data] = $r.Note
                if ($null -ne $r.Tag) {
                    $script:diarioTags[$r.Data] = $r.Tag
                }
            }
        }
    }
}

function Save-Diario {
    $lista = New-Object System.Collections.Generic.List[PSObject]
    $tutteLeDate = @($script:diarioNotes.Keys) + @($script:diarioTags.Keys) | Select-Object -Unique
    
    foreach ($key in $tutteLeDate) {
        $lista.Add([PSCustomObject]@{
            Data = $key
            Note = $script:diarioNotes[$key]
            Tag  = $script:diarioTags[$key]
        })
    }
    $lista | Export-Csv -Path $script:diarioCsvPath -NoTypeInformation -Delimiter ";" -Encoding UTF8
}

function Format-ColoredStats {
    param($rtb, $text)
    $rtb.Clear()
    $rtb.SelectionColor = [System.Drawing.Color]::Black
    $rtb.AppendText($text)

    $coloriTag = @{
        "SWOR"    = [System.Drawing.Color]::Green
        "FERIE"   = [System.Drawing.Color]::LightCoral
        "exFest"  = [System.Drawing.Color]::DarkSalmon
        "UFFICIO" = [System.Drawing.Color]::Gray
        "LREM"    = [System.Drawing.Color]::LightSeaGreen
        "ASS"     = [System.Drawing.Color]::MediumPurple
        "104"     = [System.Drawing.Color]::DarkGoldenrod
        "FEST"    = [System.Drawing.Color]::Red
    }

    foreach ($key in $coloriTag.Keys) {
        $searchStr = $key + ":"
        $pos = 0
        while (($pos = $rtb.Text.IndexOf($searchStr, $pos, [System.StringComparison]::CurrentCultureIgnoreCase)) -ne -1) {
            $rtb.SelectionStart = $pos
            $rtb.SelectionLength = $key.Length
            $rtb.SelectionColor = $coloriTag[$key]
            $rtb.SelectionFont = New-Object System.Drawing.Font($rtb.Font, [System.Drawing.FontStyle]::Bold)
            $pos += $searchStr.Length
        }
    }
    
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.SelectionLength = 0
}

function Aggiorna-ContatoriDiario {
    $dataSel = $calDiario.SelectionStart
    $meseSel = $dataSel.Month
    $annoSel = $dataSel.Year
    $giorniNelMese = [DateTime]::DaysInMonth($annoSel, $meseSel)
    
    $salvataggioNecessario = $false
    for ($i = 1; $i -le $giorniNelMese; $i++) {
        $dataCiclo = New-Object DateTime($annoSel, $meseSel, $i)
        if ($dataCiclo.DayOfWeek -eq [System.DayOfWeek]::Saturday -or $dataCiclo.DayOfWeek -eq [System.DayOfWeek]::Sunday) {
            $dataStr = $dataCiclo.ToString("yyyy-MM-dd")
            if (-not $script:diarioTags.ContainsKey($dataStr) -or [string]::IsNullOrWhiteSpace($script:diarioTags[$dataStr])) {
                $script:diarioTags[$dataStr] = "FEST"
                $salvataggioNecessario = $true
            }
        }
    }
    
    if ($salvataggioNecessario) { Save-Diario } 

    $contatori = @{ "SWOR"=0; "FERIE"=0; "exFest"=0;  "104"=0; "UFFICIO"=0; "LREM"=0; "ASS"=0; "FEST"=0 }
    $contAnno = @{ "SWOR"=0; "FERIE"=0; "exFest"=0;  "104"=0; "UFFICIO"=0; "LREM"=0; "ASS"=0; "FEST"=0 }
    
    # Ricalcolo dinamico completo di tutti i record per mantenere Mese e Anno perfettamente sincronizzati
    foreach ($dataKey in $script:diarioTags.Keys) {
        if ($dataKey -match "^(\d{4})-(\d{2})-(\d{2})$") {
            $anno = [int]$matches[1]
            $mese = [int]$matches[2]
            
            $tagVal = $script:diarioTags[$dataKey]
            
            if ($anno -eq $annoSel) {
                if ($contAnno.ContainsKey($tagVal)) {
                    $contAnno[$tagVal]++
                }
                if ($mese -eq $meseSel) {
                    if ($contatori.ContainsKey($tagVal)) {
                        $contatori[$tagVal]++
                    }
                }
            }
        }
    }
    
    $totFestivi = $contatori["FEST"]
    $totLavorativi = $giorniNelMese - $totFestivi

    $testoMese = "Mese: {0:00}/{1} (Totali: {2} | Lavorativi: {3} | Festivi: {4})`n`n" -f $meseSel, $annoSel, $giorniNelMese, $totLavorativi, $totFestivi +
                 "SWOR: $($contatori['SWOR'])  |  UFFICIO: $($contatori['UFFICIO'])  |  LREM: $($contatori['LREM'])  |  ASS: $($contatori['ASS'])`n" +
                 "FERIE: $($contatori['FERIE'])  | exFest: $($contatori['exFest']) | 104: $($contatori['104'])  |  FEST: $($contatori['FEST'])"
    Format-ColoredStats -rtb $rtbStatsMese -text $testoMese

    $testoAnno = "Anno: {0}`n`n" -f $annoSel +
                 "SWOR: $($contAnno['SWOR'])  |  UFFICIO: $($contAnno['UFFICIO'])  |  LREM: $($contAnno['LREM'])  |  ASS: $($contAnno['ASS'])`n" +
                 "FERIE: $($contAnno['FERIE'])  | exFest: $($contAnno['exFest']) | 104: $($contAnno['104'])  |  FEST: $($contAnno['FEST'])"
    Format-ColoredStats -rtb $rtbStatsAnno -text $testoAnno
}

$calDiario = New-Object System.Windows.Forms.MonthCalendar
$calDiario.Location = New-Object System.Drawing.Point(450, 20)
$tabDiario.Controls.Add($calDiario)

$lblDiarioTitle = New-Object System.Windows.Forms.Label
$lblDiarioTitle.Text = "Note dell'agenda per il giorno selezionato:"
$lblDiarioTitle.Font = $fontLabelBold
$lblDiarioTitle.Location = New-Object System.Drawing.Point(20, 20)
$lblDiarioTitle.Size = New-Object System.Drawing.Size(360, 20)
$tabDiario.Controls.Add($lblDiarioTitle)

$lblTag = New-Object System.Windows.Forms.Label
$lblTag.Text = "Tag Giornata:"
$lblTag.Font = $fontLabel
$lblTag.Location = New-Object System.Drawing.Point(20, 50)
$lblTag.Size = New-Object System.Drawing.Size(90, 20)
$tabDiario.Controls.Add($lblTag)

$cbTag = New-Object System.Windows.Forms.ComboBox
$cbTag.Location = New-Object System.Drawing.Point(110, 48)
$cbTag.Size = New-Object System.Drawing.Size(150, 25)
$cbTag.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbTag.Items.AddRange(@("", "SWOR", "FERIE","exFest", "104", "UFFICIO", "LREM", "ASS", "FEST"))
$tabDiario.Controls.Add($cbTag)

$chkAutosave = New-Object System.Windows.Forms.CheckBox
$chkAutosave.Text = "Autosalvataggio"
$chkAutosave.Location = New-Object System.Drawing.Point(270, 48) 
$chkAutosave.Size = New-Object System.Drawing.Size(140, 25)
$chkAutosave.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$chkAutosave.Checked = $true
$tabDiario.Controls.Add($chkAutosave)

$toolTipTag = New-Object System.Windows.Forms.ToolTip
$toolTipTag.AutoPopDelay = 5000
$toolTipTag.InitialDelay = 500
$toolTipTag.ReshowDelay = 500

$tabStatsCollection = New-Object System.Windows.Forms.TabControl
$tabStatsCollection.Location = New-Object System.Drawing.Point(20, 80)
$tabStatsCollection.Size = New-Object System.Drawing.Size(420, 105)

$tabMese = New-Object System.Windows.Forms.TabPage
$tabMese.Text = "Mensile"
$tabMese.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

$tabAnno = New-Object System.Windows.Forms.TabPage
$tabAnno.Text = "Annuale"
$tabAnno.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

$rtbStatsMese = New-Object System.Windows.Forms.RichTextBox
$rtbStatsMese.Dock = [System.Windows.Forms.DockStyle]::Fill
$rtbStatsMese.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$rtbStatsMese.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$rtbStatsMese.ReadOnly = $true
$rtbStatsMese.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$rtbStatsAnno = New-Object System.Windows.Forms.RichTextBox
$rtbStatsAnno.Dock = [System.Windows.Forms.DockStyle]::Fill
$rtbStatsAnno.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$rtbStatsAnno.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$rtbStatsAnno.ReadOnly = $true
$rtbStatsAnno.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$tabMese.Controls.Add($rtbStatsMese)
$tabAnno.Controls.Add($rtbStatsAnno)
$tabStatsCollection.TabPages.Add($tabMese)
$tabStatsCollection.TabPages.Add($tabAnno)
$tabDiario.Controls.Add($tabStatsCollection)

$txtDiarioNote = New-Object System.Windows.Forms.TextBox
$txtDiarioNote.Multiline = $true
$txtDiarioNote.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtDiarioNote.Location = New-Object System.Drawing.Point(20, 190)
$txtDiarioNote.Size = New-Object System.Drawing.Size(600, 450)
$txtDiarioNote.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
$tabDiario.Controls.Add($txtDiarioNote)

$btnSalvaDiario = New-Object System.Windows.Forms.Button
$btnSalvaDiario.Text = "Salva Nota e Tag"
$btnSalvaDiario.Location = New-Object System.Drawing.Point(20, 660)
$btnSalvaDiario.Size = New-Object System.Drawing.Size(600, 35)
$btnSalvaDiario.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSalvaDiario.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnSalvaDiario.ForeColor = [System.Drawing.Color]::White
$btnSalvaDiario.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabDiario.Controls.Add($btnSalvaDiario)

Load-Diario
$oggiStr = [DateTime]::Now.ToString("yyyy-MM-dd")

if ($script:diarioNotes.ContainsKey($oggiStr)) { $txtDiarioNote.Text = $script:diarioNotes[$oggiStr] }
if ($script:diarioTags.ContainsKey($oggiStr)) { $cbTag.SelectedItem = $script:diarioTags[$oggiStr] } else { $cbTag.SelectedIndex = 0 }

Aggiorna-ContatoriDiario

$calDiario.Add_DateSelected({
    $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
    $lblDiarioTitle.Text = "Note dell'agenda per il: $dataSel"
    
    Aggiorna-ContatoriDiario
    
    if ($script:diarioNotes.ContainsKey($dataSel)) { $txtDiarioNote.Text = $script:diarioNotes[$dataSel] } else { $txtDiarioNote.Text = "" }
    if ($script:diarioTags.ContainsKey($dataSel)) { $cbTag.SelectedItem = $script:diarioTags[$dataSel] } else { $cbTag.SelectedIndex = 0 }
})

$calDiario.Add_DateChanged({
    Aggiorna-ContatoriDiario
})

$cbTag.Add_SelectedIndexChanged({
    $sel = $cbTag.SelectedItem
    $cbTag.ForeColor = [System.Drawing.Color]::Black
    $txtDiarioNote.BackColor = [System.Drawing.Color]::White

    switch ($sel) {
        "SWOR" { $cbTag.BackColor = [System.Drawing.Color]::LightGreen; $toolTipTag.SetToolTip($cbTag, "SmartWorking") }
        "FERIE" { $cbTag.BackColor = [System.Drawing.Color]::LightBlue; $txtDiarioNote.BackColor = [System.Drawing.Color]::LightBlue; $toolTipTag.SetToolTip($cbTag, "Ferie") }
	    "exFest" { $cbTag.BackColor = [System.Drawing.Color]::DarkSalmon; $txtDiarioNote.BackColor = [System.Drawing.Color]::DarkSalmon; $toolTipTag.SetToolTip($cbTag, "exFest") }
        "UFFICIO" { $cbTag.BackColor = [System.Drawing.Color]::LightGray; $toolTipTag.SetToolTip($cbTag, "Lavoro in presenza") }
        "LREM" { $cbTag.BackColor = [System.Drawing.Color]::LightSeaGreen; $cbTag.ForeColor = [System.Drawing.Color]::White; $toolTipTag.SetToolTip($cbTag, "Lavoro da Remoto") }
        "ASS" { $cbTag.BackColor = [System.Drawing.Color]::MediumPurple; $cbTag.ForeColor = [System.Drawing.Color]::White; $txtDiarioNote.BackColor = [System.Drawing.Color]::MediumPurple; $toolTipTag.SetToolTip($cbTag, "Assemblea") }
        "104" { $cbTag.BackColor = [System.Drawing.Color]::Yellow; $txtDiarioNote.BackColor = [System.Drawing.Color]::Yellow; $toolTipTag.SetToolTip($cbTag, "Permesso Legge 104") }
        "FEST" { $cbTag.BackColor = [System.Drawing.Color]::LightCoral; $txtDiarioNote.BackColor = [System.Drawing.Color]::LightCoral; $toolTipTag.SetToolTip($cbTag, "Giorno Festivo (Sab/Dom/Feste)") }
        default { $cbTag.BackColor = [System.Drawing.Color]::White; $toolTipTag.SetToolTip($cbTag, "Seleziona una tipologia") }
    }

    if ($chkAutosave.Checked) {
        $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd") 
        $script:diarioTags[$dataSel] = $cbTag.SelectedItem
        $script:diarioNotes[$dataSel] = $txtDiarioNote.Text
        Save-Diario
        Aggiorna-ContatoriDiario
    }
})

$btnSalvaDiario.Add_Click({
    $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
    $script:diarioNotes[$dataSel] = $txtDiarioNote.Text
    $script:diarioTags[$dataSel] = $cbTag.SelectedItem
    Save-Diario
    Aggiorna-ContatoriDiario
    [System.Windows.Forms.MessageBox]::Show("Nota e Tag salvati per il giorno $dataSel!", "Diario Agenda", 0, 64)
})

$saveTimer = New-Object System.Windows.Forms.Timer
$saveTimer.Interval = 500 

$txtDiarioNote.Add_TextChanged({
    if ($chkAutosave.Checked -and $txtDiarioNote.Focused) {
        $saveTimer.Stop() 
        $saveTimer.Start()
    }
})

$saveTimer.Add_Tick({
    $saveTimer.Stop()
          try {
            $dataSel = $calDiario.SelectionStart.ToString("yyyy-MM-dd")
            $script:diarioNotes[$dataSel] = $txtDiarioNote.Text
            $script:diarioTags[$dataSel] = $cbTag.SelectedItem
            Save-Diario 
        } catch { }
})

# --- Setup Interfaccia Tab Pomodoro e CSV ---
$script:pomoFocusTime = 25 * 60
$script:pomoBreakTime = 5 * 60
$script:pomoSeconds = $script:pomoFocusTime
$script:pomoState = "IDLE"
$pomoIconPath = Join-Path $cartellaScript "img\pomodoro.ico"
$script:pomoCsvPath = Join-Path $cartellaScript "dati\pomodoro_tasks_$usr.csv"
$script:templatePath = Join-Path $cartellaScript "dati\pomodoro_templates_$usr.csv"
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
$btnStopPomo.Text = "Ferma! (Marcio)"
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
$btnSaveTemplate.Text = "Salva"
$btnSaveTemplate.Location = New-Object System.Drawing.Point(435, 410)
$btnSaveTemplate.Size = New-Object System.Drawing.Size(80, 28)
$tabPomodoro.Controls.Add($btnSaveTemplate)

$btnDelTemplate = New-Object System.Windows.Forms.Button
$btnDelTemplate.Text = "Elimina"
$btnDelTemplate.Location = New-Object System.Drawing.Point(520, 410)
$btnDelTemplate.Size = New-Object System.Drawing.Size(80, 28)
$tabPomodoro.Controls.Add($btnDelTemplate)

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

$btnSupporto.Add_Click({
    [System.Diagnostics.Process]::Start("mailto:danilo.iannello@inps.it?subject=Richiesta%20Supporto%20-%20Tool%20Orari")
})

$btnCalcola.Add_Click({
    $script:datiElaborati = $true
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
            $script:orarioUscitaSveglia = [TimeSpan]::Parse($txtUscitaEff.Text)
        } else {
            $script:orarioUscitaSveglia = $orarioUscitaTeorico
        }

        if ($alarmTimer.Enabled -eq $false) { $btnSveglia.Enabled = $true; $btnSveglia.BackColor = [System.Drawing.Color]::FromArgb(22, 101, 52) }

        Append-ColoredText -rtb $rtbRisultato -text "`nUscita Teorica Standard: " -color ([System.Drawing.Color]::Black) -bold $true
        Append-ColoredText -rtb $rtbRisultato -text "$($orarioUscitaTeorico.ToString("hh\:mm"))`n" -color ([System.Drawing.Color]::Blue) -bold $true
        if ([string]::IsNullOrWhiteSpace($txtUscitaEff.Text)) {
            $uscitaBuonoPasto = $oraEntrataEffettiva + [TimeSpan]::FromMinutes(390) 
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

$sysTrayIcon.Add_DoubleClick({
    $form.Show()
    $form.WindowState = "Normal"
    if ($btnSveglia.Enabled -eq $true) {
        $sysTrayIcon.Visible = $false
    }
})

$btnSveglia.Add_Click({
    if ($null -eq $script:orarioUscitaSveglia) {
        [System.Windows.Forms.MessageBox]::Show("Prima clicca 'Elabora Dati'!", "Attenzione")
        return
    }

    $target = [TimeSpan]::Parse($script:orarioUscitaSveglia.ToString().Split(' ')[-1])
    if ($target -lt [DateTime]::Now.TimeOfDay) {
        [System.Windows.Forms.MessageBox]::Show("L'orario " + $script:orarioUscitaSveglia + " è passato! Ricalcola.", "Errore")
        return
    }

    $risposta = [System.Windows.Forms.MessageBox]::Show(
        "Sveglia attivata per le $($target.ToString("hh\:mm")).`nVuoi minimizzare Ralph-o-Clock nel System Tray?", 
        "Sveglia Attiva", 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    $lblOrarioUscita.Text = "L'orario di uscita = " + $target.ToString("hh\:mm")
    $alarmTimer.Start()
    $uiTimer.Start()
    $btnSveglia.Enabled = $false
    $btnSveglia.BackColor = [System.Drawing.Color]::DarkGray
    $btnStopSveglia.Enabled = $true
    $btnStopSveglia.BackColor = [System.Drawing.Color]::Red
    $btnStopSveglia.ForeColor = [System.Drawing.Color]::White
    $sysTrayIcon.Visible = $true

    if ($risposta -eq [System.Windows.Forms.DialogResult]::Yes) {
        $sysTrayIcon.Visible = $true
        $form.WindowState = "Minimized"
        $form.Hide()
    }
})

$btnStopSveglia.Add_Click({
    $alarmTimer.Stop()
    $uiTimer.Stop()
    
    $lblCountdown.Text = ""
    $btnSveglia.Enabled = $true; 
    $btnSveglia.BackColor = [System.Drawing.Color]::FromArgb(22, 101, 52) 
    $btnStopSveglia.Enabled = $false
    $btnStopSveglia.BackColor = [System.Drawing.Color]::DarkGray
    $btnStopSveglia.ForeColor = [System.Drawing.Color]::White
    $btnStopSveglia.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $sysTrayIcon.Visible = $false
})

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
            $alarmTimer.Stop()
            $uiTimer.Stop() 
            
            $lblCountdown.Text = "È ORA DI USCIRE!"
            $btnStopSveglia.Enabled = $false
            $btnStopSveglia.BackColor = [System.Drawing.Color]::DarkGray
            $btnStopSveglia.ForeColor = [System.Drawing.Color]::White
            $btnStopSveglia.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $btnSveglia.Enabled = $true
            
            $form.Show(); $form.WindowState = "Normal"; $form.Activate()
            Play-AlarmSound
            [System.Windows.Forms.MessageBox]::Show("Orario di uscita raggiunto!")
        }
    } catch { }
})

$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
        $sysTrayIcon.Visible = $true   
        $form.Hide()
    }
})


# --- CARICAMENTO FINALE DELLE IMPOSTAZIONI ---
Load-Settings
Applica-VisibilitaUmore
Play-StartupSound
Carica-CSV

[System.Windows.Forms.Application]::Run($form)

if ($chkAutoStart.Checked) {
    $form.WindowState = "Minimized"
    $form.Hide()
    $sysTrayIcon.Visible = $true
}