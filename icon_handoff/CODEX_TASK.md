# Task for Claude Code / Codex

Integrate the provided DSLRay icon assets into the Qt application.

## Constraints

- Keep the icon concept intact: dark rounded app icon, schematic neon ray/prism mark, white convergence point, RGB decomposition.
- Use `resources/dslray_icons.qrc` for runtime Qt resources.
- Runtime icon path: `:/icons/dslray_icon.png`.
- Use `resources/icons/dslray_icon.ico` for Windows executable icon.
- Use `resources/icons/dslray_icon.icns` for macOS bundle icon.
- Do not regenerate or redesign the icon unless explicitly requested.

## Expected code changes

1. Add the qrc file to the project/build system.
2. Set `QApplication` icon in `main.cpp`.
3. Set main window icon if the app creates a QMainWindow/QWidget.
4. Add platform-specific executable/bundle icons for Windows/macOS.
5. Verify the icon appears in:
   - application window title bar
   - taskbar / Dock
   - executable file / app bundle
