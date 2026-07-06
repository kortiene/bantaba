# Homebrew formula for the `jeliyad` daemon.
#
# Filled for v0.3.1 — the first release under the Jeliya name (the project
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
  version "0.3.1"
  license "MIT OR Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "d9e61cac4eaace82d3fb5de21e0d8ae3b219ba7600fa6f830bb2aba13e2d8cd8"
    end
    on_intel do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "9da1f8f81f08177a06f4edc6a82bd096c1c80c0c6501f14b105fb04fa1465f2c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-aarch64-unknown-linux-musl.tar.gz"
      sha256 "39c39465ed8d5fdbb0f0145723cebba6a6dfc423b7897b828203cae86d382e5c"
    end
    on_intel do
      url "https://github.com/kortiene/jeliya/releases/download/v#{version}/jeliyad-v#{version}-x86_64-unknown-linux-musl.tar.gz"
      sha256 "46f21a49e5c5defd8c5cd6e8042b1f5119a0591e3880a91ba89e10abb3757d98"
    end
  end

  def install
    bin.install "jeliyad"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/jeliyad --version")
  end
end
