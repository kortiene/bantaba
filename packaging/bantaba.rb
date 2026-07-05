# Homebrew formula TEMPLATE for the `bantabad` daemon.
#
# The URLs are wired to kortiene/bantaba, but each sha256 below is a placeholder.
# This formula is unusable until a first `v*` release with attached tarballs
# exists and the release sha256 values are copied in. See packaging/README.md.
#
# This belongs in a tap, not homebrew-core: publish it as
#   kortiene/homebrew-bantaba  (repo `homebrew-bantaba`, file `Formula/bantaba.rb`)
# then users install with:
#   brew install kortiene/bantaba/bantaba
#
# To update for a new release:
#   1. Set `version` to the release number (no leading "v").
#   2. Replace each sha256 with the value from the matching release sidecar.
#      The release workflow uploads a `<asset>.sha256` next to every archive.
class Bantaba < Formula
  desc "Bantaba peer-to-peer daemon (bantabad): serves the Bantaba UI over a local WebSocket"
  homepage "https://github.com/kortiene/bantaba"
  version "0.2.0"
  license "MIT OR Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "485cf9d5a86020fa7cbfb2ed6ce1f33a8f9090374eafe24d65ddca479f858d84"
    end
    on_intel do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "59ca2968cb2a0b8bb952ccbd1ea2801d5fd7c61bddf77971be0c8b3b427eeb60"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-aarch64-unknown-linux-musl.tar.gz"
      sha256 "f58ab4b597c5b50707e26708deca66856fd542ffa3e2dd14a8bca3a019ff63a0"
    end
    on_intel do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-x86_64-unknown-linux-musl.tar.gz"
      sha256 "13d7ca5c86ebaf02b03e9ccaa77cfda40795f1ba6fb56cc8d130a9fb4f869896"
    end
  end

  def install
    bin.install "bantabad"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bantabad --version")
  end
end
