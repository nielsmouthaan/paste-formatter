# Changelog

## 0.1.0

- macOS menu bar app built in Swift with `LSUIElement` behavior for a Dockless utility experience
- `Paste` action in the menu with fixed shortcut `Control + Option + Command + V`
- Clipboard cleaning pipeline for RTF, HTML, and plain-text clipboard contents
- Formatting controls for preserving or removing fonts, colors, and links
- Default behavior that removes source fonts and colors while preserving links
- Preservation of paragraph styles during rich-text cleanup
- Automatic paste execution via simulated `Command + V` after clipboard cleanup
- `UserDefaults` persistence for menu toggle state between launches
- SwiftPM-based `.app` bundle build script that creates `dist/CleanPaste.app`
- Core formatting tests covering font/color stripping, link preservation, and optional link removal
