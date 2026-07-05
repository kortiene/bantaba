# Homebrew formula for the `jeliyad` daemon.
#
# Filled for v0.3.0 — the first release under the Jeliya name (the project
# renamed from Bantaba on 2026-07-05; docs/naming.md). Earlier releases
# shipped `bantabad-*` archives and cannot be installed by this formula.
#
# This belongs in a tap, not homebrew-core: publish it as
#   kortiene/homebrew-jeliya  (repo `homebrew-jeliya`, file `Formula/jeliya.rb`)
# then users install with:
#   brew install kortiene/jeliya/jeliya
#
# To update for a new release:
#   1. Set `version` to the release number (no leading "v").
#   2. Replace each sha256 with the value from the matching release sidecar.
#      The release workflow uploads a `<asset>.sha256` next to every archive.
class Jeliya < Formula
  desc "Jeliya peer-to-peer daemon (jeliyad): serves the Jeliya UI over a local WebSocket"
  homepage "https://github.com/kortiene/jeliya"
  version "0.3.0"
  license "MIT OR Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "2915d47df9968e2d3df9a76bc98fac2b1a954cb26dcc6d95b3c5046b5fae04f9"
    end
    on_intel do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "a798760f91575b8adfee5107097f40d22651ffeb155cc355b3f8f2b04cf41b56"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-aarch64-unknown-linux-musl.tar.gz"
      sha256 "9d10a63af57649405cc514c65b26bc16dd3dfb26d7706c7933f7e8f2358c7856"
    end
    on_intel do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-x86_64-unknown-linux-musl.tar.gz"
      sha256 "04605c8ff9fdaab4d395f27583d26fa44a052d8db2c6fec60a2fabec9c7f824b"
    end
  end

  def install
    bin.install "jeliyad"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/jeliyad --version")
  end
end
