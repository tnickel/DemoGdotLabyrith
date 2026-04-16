# Godot 4.3 Workspace & Environment Setup

Dieses Dokument beschreibt die lokale Systemkonfiguration und Ordnerstruktur für die Godot Engine. Es dient primär als Referenz für zukünftige Projekte, Workflows oder KI-Kopiloten, die in dieser Umgebung Godot-Projekte erstellen, kompilieren oder verwalten sollen.

## 1. Speicherort der Godot Engine
Godot ist in diesem Setup **nicht** tief im Betriebssystem installiert, sondern liegt portabel in einem dedizierten Tools-Verzeichnis bereit. Es handelt sich um Version **4.3 (Stable)**.

*   **Godot Executable (GUI):** `D:\AntiGravitySoftware\GodotEngine\godot.exe`
*   **Godot Console Executable:** `D:\AntiGravitySoftware\GodotEngine\Godot_v4.3-stable_win64_console.exe`

*Wichtige Regel:* Um Godot-Befehle oder Projekt-Exporte über eine Kommandozeile oder KI aufzurufen, muss stets der volle absolute Pfad zur `godot.exe` genutzt werden. Es gibt keine globale Umgebungsvariable (wie z.B. einfach `godot`).

## 2. Struktur der Projekt-Workspaces
Alle Quellcodes und Godot-Projekte befinden sich zentral im allgemeinen Git-Ordner:

*   **Workspace-Root:** `d:\AntiGravitySoftware\GitWorkspace\`

*Bekannte Godot-Projekte in diesem Ordner:*
*   `DemoGdotProject1` (Nexus Core Engine Demo)
*   `GodotVoxelPlanets` 

## 3. Best Practices & Checkliste für neue Godot Projekte
Wenn ein *zukünftiges Projekt* automatisiert oder manuell hier angelegt wird, sind folgende Dinge zu beachten:

1. **Pfad-Handling (Execution):** 
   Um ein Projekt direkt auszuführen, lautet der Befehl:
   `D:\AntiGravitySoftware\GodotEngine\godot.exe --path d:\AntiGravitySoftware\GitWorkspace\<PROJEKT_ORDNER>`
2. **Asset Import nach externen Datei-Änderungen:**
   Wenn Dateien wie `.tscn` (Szenen) oder Skripte außerhalb des Godot Editors erzeugt oder massiv verändert wurden (z.B. von einer KI), **muss** das Projekt einmal den Asset-Importer laufen lassen, bevor es fehlerfrei rendern kann.
   *Command:* `D:\AntiGravitySoftware\GodotEngine\godot.exe --headless --editor --path d:\AntiGravitySoftware\GitWorkspace\<PROJEKT_ORDNER> --quit`
3. **Renderer erzwingen:**
   Damit Godot auf Features wie SDFGI, Volumetric Fog oder GPU Particles (Compute) zugreifen kann, muss die Datei `project.godot` zwingend für die Vulkan-High-End-Pipeline deklariert sein:
   `config/features=PackedStringArray("4.3", "Forward Plus")`
4. **Hardware Kompatibilität:**
   Das System verfügt über eine rechenstarke GPU (NVIDIA Geforce RTX 4070, Vulkan). Es können daher problemlos Millionen GPU-Partikel und Screen-Space Effekte ohne externe C++-Optimierungsmodule via normalem GDScript/GLSL angesteuert werden.
