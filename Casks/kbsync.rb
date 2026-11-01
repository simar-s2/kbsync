cask "kbsync" do
  version "0.2.1"
  sha256 "839ca58de074a6c3b1b1ec3c8be41ea39d3a31a9edcde79ad1248e0670dc4f5b"

  url "https://github.com/simar-s2/kbsync/releases/download/v#{version}/kbsync-#{version}.zip"
  name "kbsync"
  desc "Menu bar app that makes the keyboard backlight follow the screen brightness"
  homepage "https://github.com/simar-s2/kbsync"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "kbsync.app"

  zap trash: "~/Library/Preferences/com.github.simar-s2.kbsync.menubar.plist"

  caveats <<~EOS
    kbsync isn't signed with a paid Apple Developer ID, so macOS blocks the
    first launch. Open kbsync once, then go to System Settings > Privacy &
    Security and click "Open Anyway".
  EOS
end
