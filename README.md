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

## Build

```bash
swift build
```
