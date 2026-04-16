@echo off
title Labyrinth Demo VR - Godot 4.3
echo Starte Labyrinth Demo im VR-Modus (PSVR2 / SteamVR)...
echo Bitte stelle sicher: PSVR2 App oder SteamVR laeuft!
echo.
"D:\AntiGravitySoftware\GodotEngine\godot.exe" --path "%~dp0." --xr-mode on
