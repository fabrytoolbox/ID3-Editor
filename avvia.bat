@echo off
REM ============================================================
REM  Launcher per ID3-Editor.ps1
REM  Versione: 1.0 (Matrix Edition)
REM ============================================================
title ID3-Editor - Matrix Edition
setlocal
cd /d "%~dp0"

REM --- 1. Controllo PowerShell 7 ---
where pwsh.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  [ERRORE] PowerShell 7 non trovato!
    echo  Scaricalo da: https://aka.ms/powershell
    echo.
    pause
    exit /b 1
)
REM --- 3. Avvio del tool ---
echo.
echo  ============================================================
echo   ID3-Editor - MATRIX EDITION
echo  ============================================================
echo   Avvio in corso...
echo.
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ID3-Editor.ps1"

REM --- 4. Gestione eventuale errore ---
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  [ERRORE] Esecuzione terminata con codice %ERRORLEVEL%.
    pause
)
endlocal
