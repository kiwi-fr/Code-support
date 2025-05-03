@echo off
chcp 65001
CLS

REM Vérifie si le script est exécuté en tant qu'administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Le script nécessite des droits administratifs. Redémarrage avec élévation de privilèges...
    powershell.exe -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

:menu
cls
echo ╔═══════════════════════════════════════════════╗
echo ║   Mises à jour & Vérifications Windows        ║
echo ╠═══════════════════════════════════════════════╣
echo ║ [1] Lancer les mises à jour                   ║
echo ║ [2] Quitter                                   ║
echo ╚═══════════════════════════════════════════════╝
echo.
set /p choix="Votre choix : "
if "%choix%"=="1" goto maj
if "%choix%"=="2" exit
goto menu

:maj
setlocal enabledelayedexpansion
set steps=8
set step1=Création point de restauration système
set step2=Mise à jour globale des applications (winget)
set step3=Réparation image système (DISM RestoreHealth)
set step4=Déclenchement recherche Windows Update
set step5=Vérification intégrité fichiers système (SFC verifyonly)
set step6=Démarrage service Windows Update
set step7=Suppression backups de service packs
set step8=Extraction du journal Windows Update

for /l %%i in (1,1,%steps%) do (
    cls
    echo === Mises à jour ^& Vérifications ===
    set "bar="
    for /l %%b in (1,1,%%i) do set "bar=!bar!#"
    for /l %%b in (1,1,!steps!) do if %%b gtr %%i set "bar=!bar!-"
    echo [!bar!] (%%i/!steps!)
    echo.
    for /l %%j in (1,1,%steps%) do (
        if %%j lss %%i (
            echo [X] !step%%j!
        ) else if %%j==%%i (
            echo [>] !step%%j!
        ) else (
            echo [ ] !step%%j!
        )
    )
    if %%i==1 powershell -NoProfile -Command "Checkpoint-Computer -Description 'Pre-Cleaning' -RestorePointType MODIFY_SETTINGS"
    if %%i==2 powershell -NoProfile -Command "if (Get-Command winget -ErrorAction SilentlyContinue) { winget upgrade --all } else { Write-Host 'Winget non installe' }"
    if %%i==3 powershell -NoProfile -Command "if (Get-Command Dism.exe -ErrorAction SilentlyContinue) { Dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart }"
    if %%i==4 powershell -NoProfile -Command "if (Get-Command wuauclt -ErrorAction SilentlyContinue) { wuauclt /detectnow /updatenow }"
    if %%i==5 powershell -NoProfile -Command "sfc /verifyonly"
    if %%i==6 powershell -NoProfile -Command "Start-Service -Name wuauserv"
    if %%i==7 powershell -NoProfile -Command "if (Get-Command Dism.exe -ErrorAction SilentlyContinue) { Dism.exe /Online /Cleanup-Image /SPSuperseded /NoRestart }"
    if %%i==8 powershell -NoProfile -Command "if (Get-Command Get-WindowsUpdateLog -ErrorAction SilentlyContinue) { Get-WindowsUpdateLog | Out-String }"
    timeout /t 1 >nul
)
echo.
echo Mises à jour et vérifications terminées.
pause
endlocal
goto menu