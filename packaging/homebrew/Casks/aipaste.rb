cask "aipaste" do
  version "0.1.1-icon"
  sha256 :no_check

  url "https://github.com/AiPaste/AiPaste/releases/download/v#{version}/AiPaste-#{version}-macOS.zip"
  name "AiPaste"
  desc "Native macOS clipboard manager with groups, search, and quick paste"
  homepage "https://github.com/AiPaste/AiPaste"

  app "AiPaste.app"

  zap trash: [
    "~/Library/Application Support/AiPaste",
    "~/Library/Caches/com.huike.aipaste",
    "~/Library/Preferences/com.huike.aipaste.plist",
  ]
end
