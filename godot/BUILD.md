# Build & Export — Mystic Emporium Automata

## Requisitos
- Godot 4.6.x (`godot --version` → `4.6.2.stable...`)
- Export templates instalados (Godot Editor → Editor → Manage Export Templates → Download)
  - Linux templates: ~600 MB
  - Windows templates: necesarios para cross-compile

## Builds locales

Los `export_presets.cfg` ya están configurados con 2 presets:

### Linux x86_64

```bash
cd ~/Proyectos/MysticEmporium/godot/
godot --headless --export-release "Linux/X11" ../builds/linux/MysticEmporium.x86_64
chmod +x ../builds/linux/MysticEmporium.x86_64
```

### Windows x86_64 (cross-compile desde Linux)

```bash
cd ~/Proyectos/MysticEmporium/godot/
godot --headless --export-release "Windows Desktop" ../builds/windows/MysticEmporium.exe
```

Requiere `wine` para que algunos pasos funcionen, pero el binario sale igual.

### Verificar build

```bash
# Linux
../builds/linux/MysticEmporium.x86_64

# Windows (con wine)
wine ../builds/windows/MysticEmporium.exe
```

## AppImage (opcional)

Para distribución Linux más limpia, empaqueta el binario como AppImage:

```bash
# Requiere appimagetool
mkdir -p MysticEmporium.AppDir/usr/bin
cp ../builds/linux/MysticEmporium.x86_64 MysticEmporium.AppDir/usr/bin/MysticEmporium
# Añadir .desktop, icon.png, AppRun…
appimagetool MysticEmporium.AppDir
```

## Saves del usuario

Los saves van a:
- **Linux**: `~/.local/share/godot/app_userdata/Mystic Emporium Automata/save_slot_N.json`
- **Windows**: `%APPDATA%\Godot\app_userdata\Mystic Emporium Automata\save_slot_N.json`

3 slots disponibles (N = 0, 1, 2).
