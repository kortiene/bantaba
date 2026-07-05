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
  version "0.1.0"
  license "MIT OR Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "2de1288e906278dcc1a7feeefaa11064d06c3c14b80635a04e2b277dae317ac5"
    end
    on_intel do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "606be521804745bafe29b067b0ed37897033e1fc1a1c3c364228b26234192057"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-aarch64-unknown-linux-musl.tar.gz"
      sha256 "83dd9036b450528ae62c6ff2c767604c3c90e51530dbf10de863c06694dc697c"
    end
    on_intel do
      url "https://github.com/kortiene/bantaba/releases/download/v#{version}/bantabad-v#{version}-x86_64-unknown-linux-musl.tar.gz"
      sha256 "96d74e6b510804b152e0dfa42d52d26e5aff1a8b7bc08af92a9d056b5dfa5bb2"
    end
  end

  def install
    bin.install "bantabad"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bantabad --version")
  end
end
