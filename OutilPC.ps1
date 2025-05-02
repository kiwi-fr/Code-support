If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Relancement en mode administrateur..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Le script doit être exécuté en mode administrateur.","Erreur d'exécution", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    Exit
}
function Show-Menu {
    
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   Outil d'entretien du système Windows       ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] Analyse complète du PC" -ForegroundColor Green
    Write-Host "[2] Nettoyage complet" -ForegroundColor Green
    Write-Host "[3] Mises à jour & Vérifications" -ForegroundColor Green
    Write-Host "[4] Quitter" -ForegroundColor Red
    Write-Host ""
}

function Show-ProgressBar {
    param($Percent, $Message)
    $width = 50
    $done = [math]::Round($Percent * $width / 100)
    $bar = ('█' * $done) + ('░' * ($width - $done))
    $color = if ($Percent -eq 100) { 'Green' } elseif ($Percent -ge 80) { 'Yellow' } else { 'Cyan' }
    Write-Host -NoNewline "`r[$bar] $Percent% - $Message" -ForegroundColor $color
}

function SpinnerStep {
    param($ScriptBlock, $Message, [ref]$Result)
    $spinner = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $i = 0
    $job = Start-Job $ScriptBlock
    while ($job.State -eq 'Running') {
        Write-Host -NoNewline "`r$($spinner[$i % $spinner.Length]) $Message" -ForegroundColor Magenta
        Start-Sleep -Milliseconds 100
        $i++
    }
    $Result.Value = Receive-Job $job -Wait
    Write-Host "`r$Message ... terminé. " -ForegroundColor Green
}

function Show-Step {
    param($StepIndex, $TotalSteps, $Label, $Status)
    $percent = [math]::Round(($StepIndex+1)*100/$TotalSteps)
    $width = 50
    $done = [math]::Round($percent * $width / 100)
    $bar = ('█' * $done) + ('░' * ($width - $done))
    $color = switch ($Status) {
        'done' { 'Green' }
        'run'  { 'Yellow' }
        default { 'DarkGray' }
    }
    Write-Host "[$bar] $percent% - $Label" -ForegroundColor $color
}

function Test-Command {
    param($Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Analyse-Systeme {
    $steps = @(
        @{ cmd = { if (Test-Command 'bootrec') { bootrec /rebuildbcd 2>&1 } }; label = "Reconstruit le BCD (bootrec /rebuildbcd)" }
        @{ cmd = { Get-PhysicalDisk | Select FriendlyName | Format-Table | Out-String }; label = "Nom des disques physiques" }
        @{ cmd = { Get-PhysicalDisk | Select HealthStatus | Format-Table | Out-String }; label = "Santé des disques physiques" }
        @{ cmd = { if (Test-Command 'bootrec') { bootrec /fixmbr 2>&1 } }; label = "Réparation du MBR (bootrec /fixmbr)" }
        @{ cmd = { Get-Volume | Select-Object DriveLetter | Format-Table -AutoSize | Out-String }; label = "Lettres des volumes" }
        @{ cmd = { Get-Volume | Select-Object SizeRemaining, Size | Format-Table -AutoSize | Out-String }; label = "Espace restant et taille des volumes" }
        @{ cmd = { ipconfig /flushdns 2>&1; ipconfig /registerdns 2>&1 } ; label = "Flush et registre DNS" }
        @{ cmd = { if (Test-Command 'Dism.exe') { Dism.exe /Online /Cleanup-Image /ScanHealth /NoRestart /Format:Table 2>&1 } }; label = "Vérification image système (DISM ScanHealth)" }
        @{ cmd = { if (Test-Command 'sfc') { sfc /scannow 2>&1 } }; label = "Réparation fichiers système (SFC)" }
        @{ cmd = { if (Test-Command 'chkdsk') { chkdsk C: /scan /perf 2>&1 } }; label = "Analyse rapide disque C: (chkdsk /scan /perf)" }
        @{ cmd = { Get-Volume | Get-Partition | Get-PhysicalDisk | Select-Object FriendlyName, MediaType, OperationalStatus, HealthStatus | Format-Table | Out-String }; label = "Etat des disques physiques" }
    )
    $total = $steps.Count
    $results = @()
    for ($i = 0; $i -lt $total; $i++) {
        Clear-Host
        for ($j = 0; $j -lt $total; $j++) {
            if ($j -lt $i) { Show-Step $j $total $steps[$j].label 'done' }
            elseif ($j -eq $i) { Show-Step $j $total $steps[$j].label 'run' }
            else { Show-Step $j $total $steps[$j].label 'wait' }
        }
        $out = ""
        SpinnerStep $steps[$i].cmd $steps[$i].label ([ref]$out)
        $results += @{ label = $steps[$i].label; output = $out }
        Write-Host "`n--- Résultat étape : $($steps[$i].label) ---" -ForegroundColor Cyan
        Write-Host "$out" -ForegroundColor Gray
        Start-Sleep 0.5
    }
    Write-Host "`n==== Analyse complète terminée. ====" -ForegroundColor Green
    Pause
    Clear-Host
}

function Nettoyage-Systeme {
    $steps = @(
        @{ cmd = { Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue }; label = "Suppression fichiers temporaires utilisateur" }
        @{ cmd = { Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue }; label = "Nettoyage dossier Temp Windows" }
        @{ cmd = { if (Test-Command 'cleanmgr') { cleanmgr /verylowdisk /autoclean } }; label = "Nettoyage disque automatique (cleanmgr)" }
        @{ cmd = { if (Test-Command 'Dism.exe') { Dism.exe /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1 } }; label = "Nettoyage WinSxS (DISM)" }
        @{ cmd = { ipconfig /flushdns 2>&1 }; label = "Vidage du cache DNS" }
        @{ cmd = { netsh winsock reset 2>&1 }; label = "Réinitialisation Winsock" }
        @{ cmd = { netsh int ip reset 2>&1 }; label = "Réinitialisation TCP/IP" }
        @{ cmd = { vssadmin delete shadows /for=C: /all /quiet 2>&1 }; label = "Suppression points de restauration" }
        @{ cmd = { Clear-EventLog -LogName Application, System }; label = "Effacement journaux d'événements" }
        @{ cmd = { defrag C: /O /U /V 2>&1 }; label = "Défragmentation/optimisation disque C:" }
        @{ cmd = { net stop wuauserv; net stop bits; Rename-Item -Path C:\Windows\SoftwareDistribution -NewName SoftwareDistribution.old -ErrorAction SilentlyContinue; net start wuauserv; net start bits }; label = "Nettoyage cache Windows Update" }
        @{ cmd = { Optimize-VHD -Path "$($env:SYSTEMDRIVE)\*.vhd" -Mode Full -Verbose }; label = "Optimisation des disques virtuels" }
        @{ cmd = { vssadmin delete shadows /all /quiet; powercfg -h off; schtasks /Delete /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /F }; label = "Désactivation hibernation et tâches superflues" }
        @{ cmd = { wmic product where "vendor like '%%adobe%%'" call uninstall /nointeractive; wmic bios get serialnumber > $null }; label = "Désinstallation silencieuse de logiciels ciblés" }
        @{ cmd = { Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -EA 0; Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*" -Recurse -Force -EA 0 }; label = "Suppression historique récent et thumbnails" }
        @{ cmd = { netsh interface ipv4 reset; netsh interface ipv6 reset; netsh http flush logbuffer; netsh winsock reset catalog }; label = "Réinitialisation complète des piles réseau" }
        @{ cmd = { dism /Online /Cleanup-Image /AnalyzeComponentStore; compact /CompactOS:always }; label = "Optimisation de l'empreinte disque système" }
    )
    $total = $steps.Count
    $results = @()
    for ($i = 0; $i -lt $total; $i++) {
        Clear-Host
        for ($j = 0; $j -lt $total; $j++) {
            if ($j -lt $i) { Show-Step $j $total $steps[$j].label 'done' }
            elseif ($j -eq $i) { Show-Step $j $total $steps[$j].label 'run' }
            else { Show-Step $j $total $steps[$j].label 'wait' }
        }
        $out = ""
        SpinnerStep $steps[$i].cmd $steps[$i].label ([ref]$out)
        $results += @{ label = $steps[$i].label; output = $out }
        Write-Host "`n--- Résultat étape : $($steps[$i].label) ---" -ForegroundColor Cyan
        Write-Host "$out" -ForegroundColor Gray
        Start-Sleep 0.5
    }
    Write-Host "`n==== Nettoyage complet terminé. ====" -ForegroundColor Green
    Pause
    Clear-Host
}

function MAJ-Systeme {
    $steps = @(
        @{ cmd = { Checkpoint-Computer -Description "Pre-Cleaning" -RestorePointType MODIFY_SETTINGS }; label = "Création d'un point de restauration système" }
        @{ cmd = { if (Test-Command 'winget') { winget upgrade --all } else { "Winget non installé" } }; label = "Mise à jour globale des applications (winget)" }
        @{ cmd = { if (Test-Command 'Dism.exe') { Dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart 2>&1 } }; label = "Réparation image système (DISM RestoreHealth)" }
        @{ cmd = { if (Test-Command 'wuauclt') { wuauclt /detectnow /updatenow } }; label = "Déclenchement recherche Windows Update" }
        @{ cmd = { sfc /verifyonly 2>&1 }; label = "Vérification intégrité fichiers système (SFC verifyonly)" }
        @{ cmd = { Start-Service -Name wuauserv }; label = "Démarrage service Windows Update" }
        @{ cmd = { if (Test-Command 'Dism.exe') { Dism.exe /Online /Cleanup-Image /SPSuperseded /NoRestart 2>&1 } }; label = "Suppression backups de service packs" }
        @{ cmd = { Get-WindowsUpdateLog | Out-String }; label = "Extraction du journal Windows Update" }
    )
    $total = $steps.Count
    $results = @()
    for ($i = 0; $i -lt $total; $i++) {
        Clear-Host
        for ($j = 0; $j -lt $total; $j++) {
            if ($j -lt $i) { Show-Step $j $total $steps[$j].label 'done' }
            elseif ($j -eq $i) { Show-Step $j $total $steps[$j].label 'run' }
            else { Show-Step $j $total $steps[$j].label 'wait' }
        }
        $out = ""
        SpinnerStep $steps[$i].cmd $steps[$i].label ([ref]$out)
        $results += @{ label = $steps[$i].label; output = $out }
        Write-Host "`n--- Résultat étape : $($steps[$i].label) ---" -ForegroundColor Cyan
        Write-Host "$out" -ForegroundColor Gray
        Start-Sleep 0.5
    }
    Write-Host "`n==== Vérification et mises à jour terminées. ====" -ForegroundColor Green
    Pause
    Clear-Host
}

do {
    Show-Menu
    $choice = Read-Host "Sélectionnez une option (1-4)"
    switch ($choice) {
        '1' { Analyse-Systeme }
        '2' { Nettoyage-Systeme }
        '3' { MAJ-Systeme }
        '4' { Write-Host "`nAu revoir !" -ForegroundColor Yellow }
        default { Write-Host "Choix invalide, recommencez." -ForegroundColor Red; Start-Sleep 1 }
    }
} while ($choice -ne '4')

