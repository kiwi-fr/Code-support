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
echo ║   Analyse complète du PC                      ║
echo ╠═══════════════════════════════════════════════╣
echo ║ [1] Lancer l'analyse                          ║
echo ║ [2] Quitter                                   ║
echo ╚═══════════════════════════════════════════════╝
echo.
set /p choix="Votre choix : "
if "%choix%"=="1" goto analyse
if "%choix%"=="2" exit
goto menu

:analyse
cls
setlocal enabledelayedexpansion
set steps=10
set step1=Analyse de la fragmentation (sans défragmenter)
set step2=Optimisation intelligente des volumes (SSD/HDD)
set step3=Reconstruit le BCD
set step4=Réparation du MBR
set step5=Infos disques physiques
set step6=Infos volumes
set step7=Infos partitions/disques
set step8=Flush DNS
set step9=Vérification image système
set step10=Vérification fichiers système

for /l %%i in (1,1,%steps%) do (
    cls
    echo === Analyse complète du PC ===
    for /l %%j in (1,1,%steps%) do (
        if %%j lss %%i (
            echo [X] !step%%j!
        ) else if %%j==%%i (
            echo [>] !step%%j!
        ) else (
            echo [ ] !step%%j!
        )
    )
    if %%i==1 powershell -NoProfile -Command "Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object { defrag $_.DriveLetter':' /A /V }"
    if %%i==2 powershell -NoProfile -Command "Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object { Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -Verbose }"
    if %%i==3 powershell -NoProfile -Command "if (Get-Command bootrec -ErrorAction SilentlyContinue) { bootrec /rebuildbcd }"
    if %%i==4 powershell -NoProfile -Command "if (Get-Command bootrec -ErrorAction SilentlyContinue) { bootrec /fixmbr }"
    if %%i==5 powershell -NoProfile -Command "Get-PhysicalDisk | Format-Table"
    if %%i==6 powershell -NoProfile -Command "Get-Volume | Format-Table"
    if %%i==7 powershell -NoProfile -Command "Get-Volume | Get-Partition | Get-PhysicalDisk | Format-Table"
    if %%i==8 powershell -NoProfile -Command "ipconfig /flushdns; ipconfig /registerdns"
    if %%i==9 powershell -NoProfile -Command "if (Get-Command Dism.exe -ErrorAction SilentlyContinue) { Dism.exe /Online /Cleanup-Image /ScanHealth /NoRestart /Format:Table }"
    if %%i==10 powershell -NoProfile -Command "if (Get-Command sfc -ErrorAction SilentlyContinue) { sfc /scannow }"
    timeout /t 1 >nul
)
echo.
echo Analyse terminée.
pause
endlocal
goto menu