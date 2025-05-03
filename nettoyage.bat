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
echo ║   Nettoyage complet du PC                     ║
echo ╠═══════════════════════════════════════════════╣
echo ║ [1] Lancer le nettoyage                       ║
echo ║ [2] Quitter                                   ║
echo ╚═══════════════════════════════════════════════╝
echo.
set /p choix="Votre choix : "
if "%choix%"=="1" goto nettoyage
if "%choix%"=="2" exit
goto menu

:nettoyage
cls
setlocal enabledelayedexpansion
set steps=15
set step1=Suppression fichiers temporaires utilisateur
set step2=Nettoyage dossier Temp Windows
set step3=Nettoyage disque automatique
set step4=Nettoyage WinSxS (DISM)
set step5=Vidage du cache DNS
set step6=Réinitialisation Winsock et TCP/IP
set step7=Suppression points de restauration
set step8=Effacement journaux d'événements
set step9=Défragmentation/optimisation disque C:
set step10=Nettoyage cache Windows Update
set step11=Nettoyage du dossier Prefetch
set step12=Suppression des miniatures (thumbnails)
set step13=Nettoyage de la corbeille pour tous les utilisateurs
set step14=Purge du cache Delivery Optimization
set step15=Nettoyage du cache Microsoft Store

for /l %%i in (1,1,%steps%) do (
    cls
    echo === Nettoyage complet ===
    for /l %%j in (1,1,%steps%) do (
        if %%j lss %%i (
            echo [X] !step%%j!
        ) else if %%j==%%i (
            echo [>] !step%%j!
        ) else (
            echo [ ] !step%%j!
        )
    )
    if %%i==1 powershell -NoProfile -Command "Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue"
    if %%i==2 powershell -NoProfile -Command "Remove-Item C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue"
    if %%i==3 powershell -NoProfile -Command "if (Get-Command cleanmgr -ErrorAction SilentlyContinue) { cleanmgr /verylowdisk /autoclean }"
    if %%i==4 powershell -NoProfile -Command "if (Get-Command Dism.exe -ErrorAction SilentlyContinue) { Dism.exe /Online /Cleanup-Image /StartComponentCleanup /NoRestart }"
    if %%i==5 powershell -NoProfile -Command "ipconfig /flushdns"
    if %%i==6 powershell -NoProfile -Command "netsh winsock reset; netsh int ip reset"
    if %%i==7 powershell -NoProfile -Command "vssadmin delete shadows /for=C: /all /quiet"
    if %%i==8 powershell -NoProfile -Command "Clear-EventLog -LogName Application, System"
    if %%i==9 powershell -NoProfile -Command "defrag C: /O /U /V"
    if %%i==10 powershell -NoProfile -Command "net stop wuauserv; net stop bits; Rename-Item -Path C:\Windows\SoftwareDistribution -NewName SoftwareDistribution.old -ErrorAction SilentlyContinue; net start wuauserv; net start bits"
    if %%i==11 powershell -NoProfile -Command "Remove-Item C:\Windows\Prefetch\* -Force -ErrorAction SilentlyContinue"
    if %%i==12 powershell -NoProfile -Command "Remove-Item $env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_* -Force -ErrorAction SilentlyContinue"
    if %%i==13 powershell -NoProfile -Command "Clear-RecycleBin -Force"
    if %%i==14 powershell -NoProfile -Command "Remove-Item C:\Windows\SoftwareDistribution\DeliveryOptimization\* -Recurse -Force -ErrorAction SilentlyContinue"
    if %%i==15 powershell -NoProfile -Command "wsreset.exe"
    timeout /t 1 >nul
)
echo.
echo Nettoyage terminé.
pause
endlocal
goto menu