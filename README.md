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

## CLI

AiPaste now also supports a command-line mode. You can use the wrapper:

```bash
./bin/aipaste help
```

Or call the executable directly:

```bash
swift run AiPaste -- cli help
```

Supported commands:

```bash
./bin/aipaste panel show
./bin/aipaste panel hide
./bin/aipaste panel toggle
./bin/aipaste settings open
./bin/aipaste capture

./bin/aipaste list
./bin/aipaste list --search swift --limit 10
./bin/aipaste list --group group-1 --json

./bin/aipaste items copy 1
./bin/aipaste items paste 1
./bin/aipaste items pin 1
./bin/aipaste items unpin 1
./bin/aipaste items delete 1
./bin/aipaste items move 1 clipboard
./bin/aipaste items move 1 group-1

./bin/aipaste groups list
./bin/aipaste groups create work
./bin/aipaste groups rename group-1 archive
./bin/aipaste groups color archive blue
./bin/aipaste groups delete archive

./bin/aipaste ignore list
./bin/aipaste ignore add --app /Applications/Keychain\\ Access.app
./bin/aipaste ignore add --bundle-id com.apple.finder --name Finder
./bin/aipaste ignore remove com.apple.finder

./bin/aipaste config list
./bin/aipaste config get paste-destination
./bin/aipaste config set run-in-background false
./bin/aipaste config set history-retention week
```

Notes:

- `panel ...` and `settings open` target a running AiPaste app instance.
- `items paste` requires macOS Accessibility permission.
- Index-based item commands use the same top-to-bottom order as `list`.

To enable automatic paste-back into the previously active app, grant AiPaste Accessibility permission in macOS System Settings.

`Open at login` uses macOS ServiceManagement and works best when AiPaste is installed as a normal app bundle instead of only running through `swift run`.

`Run in background` controls whether AiPaste stays resident as a menu bar app after its panel and settings window are closed. When disabled, the app quits once no UI is visible.

`Sound effects` now plays real system sounds for clipboard capture, successful paste-to-app actions, and permission or system-operation failures.

`Automatic updates` now uses the standard Sparkle in-app updater. Packaged builds check the Sparkle appcast in the background, download updates inside the app, and relaunch automatically after installation instead of sending users to the browser for a zip download.

## Build

```bash
swift build
```

## Website

The repository now includes a static marketing site for GitHub Pages in [`docs/`](docs).

Local preview:

```bash
./scripts/serve_website.sh
```

To publish it:

1. Push the repository to GitHub.
2. Open `Settings -> Pages`.
3. Set `Build and deployment` to `Deploy from a branch`.
4. Select the current branch and the `/docs` folder.
5. Save, then wait for GitHub Pages to publish.

The page entry point is `docs/index.html`.

## Release App

Build a local `.app` bundle and release zip:

```bash
./scripts/build_release_app.sh 0.1.0
```

To build a Sparkle-enabled bundle, provide the public EdDSA key and appcast URL:

```bash
SPARKLE_PUBLIC_ED_KEY="your-public-ed25519-key" \
SPARKLE_APPCAST_URL="https://aipaste.github.io/AiPaste/appcast.xml" \
./scripts/build_release_app.sh 0.1.0
```

Generate or refresh the appcast feed from packaged archives:

```bash
SPARKLE_PRIVATE_KEY="your-private-key-secret" \
SPARKLE_DOWNLOAD_URL_PREFIX="https://github.com/AiPaste/AiPaste/releases/download/v0.1.0/" \
SPARKLE_RELEASE_LINK="https://github.com/AiPaste/AiPaste/releases/tag/v0.1.0" \
./scripts/generate_appcast.sh dist docs/appcast.xml
```

GitHub Actions workflow:

- file: `.github/workflows/release-app.yml`
- trigger: push a tag like `v0.1.0`
- output: `dist/AiPaste.app` and `dist/AiPaste-<version>-macOS.zip`
- release: automatically creates a GitHub Release on tag pushes, generates `docs/appcast.xml`, and uploads the packaged zip
- required secrets: `SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_KEY`

Create an annotated release tag with both current and previous release change summaries:

```bash
./scripts/create_release_tag.sh v0.1.4
./scripts/create_release_tag.sh v0.1.4 --push
```

## Homebrew

After the first tagged GitHub release is published, you can install AiPaste with Homebrew:

```bash
brew tap AiPaste/aipaste
brew install --cask aipaste
```

Upgrade:

```bash
brew update
brew upgrade --cask aipaste
```

The Homebrew cask template lives at `packaging/homebrew/Casks/aipaste.rb` and the release workflow publishes it into the dedicated tap repository `AiPaste/homebrew-aipaste` after each tagged release.
