import Darwin
import Foundation
import OSLog

@MainActor
final class CLIToolInstaller: ObservableObject {
    static let shared = CLIToolInstaller()

    @Published private(set) var isInstalled = false
    @Published private(set) var commandPath = ""
    @Published private(set) var shellConfigPath = ""
    @Published private(set) var statusMessage = "Install the `aipaste` command so it works in any new terminal window."

    private let logger = Logger(subsystem: "AiPaste", category: "CLIInstaller")
    private let fileManager = FileManager.default

    private let pathMarkerStart = "# >>> AiPaste CLI >>>"
    private let pathMarkerEnd = "# <<< AiPaste CLI <<<"

    private init() {
        refreshStatus()
    }

    func install() {
        do {
            let commandURL = try commandURL()
            let shellProfile = try shellProfile()

            try fileManager.createDirectory(at: commandURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try writeWrapperScript(to: commandURL)
            try installPathBlock(in: shellProfile)

            refreshStatus()
            statusMessage = "CLI installed. Open a new terminal window, then run `aipaste help`."
            logger.debug("installed CLI wrapper at \(commandURL.path, privacy: .public)")
        } catch {
            statusMessage = error.localizedDescription
            SoundEffectPlayer.shared.play(.error)
            logger.error("failed to install CLI: \(error.localizedDescription, privacy: .public)")
            refreshStatus()
        }
    }

    func refreshStatus() {
        do {
            let commandURL = try commandURL()
            let shellProfile = try shellProfile()

            commandPath = commandURL.path
            shellConfigPath = shellProfile.fileURL.path

            let wrapperExists = fileManager.isExecutableFile(atPath: commandURL.path)
            let profileHasBlock = shellConfigContainsManagedBlock(shellProfile.fileURL)
            isInstalled = wrapperExists && profileHasBlock

            if isInstalled {
                statusMessage = "Installed at \(commandURL.path). New terminal windows will pick up `aipaste` automatically."
            } else if wrapperExists {
                statusMessage = "CLI wrapper exists, but PATH is not configured yet. Reinstall to finish setup."
            } else {
                statusMessage = "Install the `aipaste` command so it works in any new terminal window."
            }
        } catch {
            commandPath = ""
            shellConfigPath = ""
            isInstalled = false
            statusMessage = error.localizedDescription
        }
    }

    private func commandURL() throws -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("aipaste", isDirectory: false)
    }

    private func writeWrapperScript(to commandURL: URL) throws {
        let script = try wrapperScript()
        try script.write(to: commandURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandURL.path)
    }

    private func wrapperScript() throws -> String {
        guard let executablePath = Bundle.main.executableURL?.path ?? ProcessInfo.processInfo.arguments.first else {
            throw CLIInstallerError.unableToResolveExecutable
        }

        let bundlePath = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL.path : ""
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.huike.aipaste"
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "AiPaste"

        return """
#!/usr/bin/env bash
set -euo pipefail

CURRENT_EXECUTABLE=\(shellQuoted(executablePath))
CURRENT_BUNDLE=\(shellQuoted(bundlePath))
APP_BUNDLE_IDENTIFIER=\(shellQuoted(bundleIdentifier))
APP_NAME=\(shellQuoted(appName))

if [[ -n "${AIPASTE_EXECUTABLE:-}" ]] && [[ -x "${AIPASTE_EXECUTABLE}" ]]; then
  exec "${AIPASTE_EXECUTABLE}" cli "$@"
fi

if [[ -x "${CURRENT_EXECUTABLE}" ]]; then
  exec "${CURRENT_EXECUTABLE}" cli "$@"
fi

if [[ -n "${CURRENT_BUNDLE}" ]] && [[ -x "${CURRENT_BUNDLE}/Contents/MacOS/${APP_NAME}" ]]; then
  exec "${CURRENT_BUNDLE}/Contents/MacOS/${APP_NAME}" cli "$@"
fi

if command -v mdfind >/dev/null 2>&1; then
  FOUND_APP="$(mdfind "kMDItemCFBundleIdentifier == '${APP_BUNDLE_IDENTIFIER}'" | head -n 1 || true)"
  if [[ -n "${FOUND_APP}" ]] && [[ -x "${FOUND_APP}/Contents/MacOS/${APP_NAME}" ]]; then
    exec "${FOUND_APP}/Contents/MacOS/${APP_NAME}" cli "$@"
  fi
fi

echo "${APP_NAME}.app could not be found. Reinstall the CLI from AiPaste Settings > General > Command Line." >&2
exit 1
"""
    }

    private func shellProfile() throws -> ShellProfile {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let loginShell = currentLoginShell()
        let shellName = URL(fileURLWithPath: loginShell).lastPathComponent.lowercased()

        switch shellName {
        case "fish":
            return ShellProfile(
                fileURL: homeURL
                    .appendingPathComponent(".config", isDirectory: true)
                    .appendingPathComponent("fish", isDirectory: true)
                    .appendingPathComponent("config.fish", isDirectory: false),
                block: fishPathBlock
            )
        case "bash":
            return ShellProfile(
                fileURL: homeURL.appendingPathComponent(".bash_profile", isDirectory: false),
                block: posixPathBlock
            )
        case "zsh":
            return ShellProfile(
                fileURL: homeURL.appendingPathComponent(".zshrc", isDirectory: false),
                block: posixPathBlock
            )
        default:
            return ShellProfile(
                fileURL: homeURL.appendingPathComponent(".profile", isDirectory: false),
                block: posixPathBlock
            )
        }
    }

    private func installPathBlock(in shellProfile: ShellProfile) throws {
        try fileManager.createDirectory(at: shellProfile.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let existing = (try? String(contentsOf: shellProfile.fileURL, encoding: .utf8)) ?? ""
        let updated = replacingManagedBlock(in: existing, with: shellProfile.block)

        try updated.write(to: shellProfile.fileURL, atomically: true, encoding: .utf8)
    }

    private func replacingManagedBlock(in text: String, with block: String) -> String {
        guard let startRange = text.range(of: pathMarkerStart),
              let endRange = text.range(of: pathMarkerEnd) else {
            if text.isEmpty {
                return block + "\n"
            }

            let suffix = text.hasSuffix("\n") ? "" : "\n"
            return text + suffix + "\n" + block + "\n"
        }

        let replacementRange = startRange.lowerBound..<endRange.upperBound
        return text.replacingCharacters(in: replacementRange, with: block)
    }

    private func shellConfigContainsManagedBlock(_ fileURL: URL) -> Bool {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return contents.contains(pathMarkerStart) && contents.contains(pathMarkerEnd)
    }

    private func currentLoginShell() -> String {
        if let passwd = getpwuid(getuid()), let shell = passwd.pointee.pw_shell {
            let shellPath = String(cString: shell)
            if !shellPath.isEmpty {
                return shellPath
            }
        }

        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }

        return "/bin/zsh"
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private var posixPathBlock: String {
        """
\(pathMarkerStart)
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
\(pathMarkerEnd)
"""
    }

    private var fishPathBlock: String {
        """
\(pathMarkerStart)
if test -d $HOME/.local/bin
    if not contains $HOME/.local/bin $PATH
        fish_add_path -g $HOME/.local/bin
    end
end
\(pathMarkerEnd)
"""
    }
}

private struct ShellProfile {
    let fileURL: URL
    let block: String
}

private enum CLIInstallerError: LocalizedError {
    case unableToResolveExecutable

    var errorDescription: String? {
        switch self {
        case .unableToResolveExecutable:
            return "AiPaste could not find its own executable, so the CLI wrapper could not be created."
        }
    }
}
