# AiPaste

AiPaste is a native macOS clipboard app built with SwiftUI. It monitors the system pasteboard, stores recent text clips locally, and presents them in a fast horizontal card layout inspired by the provided reference.

## Features

- Native SwiftUI desktop UI with glassmorphism shell and large clipboard cards
- Automatic clipboard monitoring with frontmost-app detection
- Search and source-based filtering
- One-click copy, pin, delete, and persistent local history
- Zero web runtime and zero third-party dependencies

## Run

```bash
swift run
```

To enable automatic paste-back into the previously active app, grant AiPaste Accessibility permission in macOS System Settings.

`Open at login` uses macOS ServiceManagement and works best when AiPaste is installed as a normal app bundle instead of only running through `swift run`.

`Run in background` controls whether AiPaste stays resident as a menu bar app after its panel and settings window are closed. When disabled, the app quits once no UI is visible.

`Sound effects` now plays real system sounds for clipboard capture, successful paste-to-app actions, and permission or system-operation failures.

## Build

```bash
swift build
```
