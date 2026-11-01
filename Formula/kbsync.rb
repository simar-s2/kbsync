class Kbsync < Formula
  desc "Make the MacBook keyboard backlight follow the screen brightness"
  homepage "https://github.com/simar-s2/kbsync"
  url "https://github.com/simar-s2/kbsync/releases/download/v0.2.0/kbsync-0.2.0-src.tar.gz"
  sha256 "2341b4f0a4b24b7b57691ab4e67ab5e662a9c01bd4723bdc631cded9fa01c83a"
  license "MIT"
  head "https://github.com/simar-s2/kbsync.git", branch: "main"

  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "--configuration", "release", "--product", "kbsync"
    bin.install ".build/release/kbsync"
  end

  def caveats
    <<~EOS
      To run kbsync in the background and at login:
        kbsync install
    EOS
  end

  test do
    assert_match "kbsync #{version}", shell_output("#{bin}/kbsync version")
    assert_match "--max", shell_output("#{bin}/kbsync help")
  end
end
