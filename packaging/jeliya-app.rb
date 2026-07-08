# Homebrew CASK for the Jeliya desktop app (Jeliya.app + bundled jeliyad
# sidecar) — the graphical counterpart of the `jeliya` formula (jeliya.rb),
# which installs the bare daemon.
#
# NOT YET FILLED: placeholders below are completed at the first app release
# (the release workflow's `macos-app` job uploads
# `Jeliya-v<version>-macos.dmg` + `.sha256` next to the daemon archives).
#
# This belongs in the same tap as the formula:
#   kortiene/homebrew-jeliya, file `Casks/jeliya.rb`
# then users install with:
#   brew install --cask kortiene/jeliya/jeliya
#
# To update for a new release:
#   1. Set `version` to the APP version (pubspec.yaml, no leading "v") and
#      `release_tag` to the git tag the DMG was attached to.
#   2. Replace sha256 with the value from the `.sha256` release sidecar.
#
# Until notarization is live (Developer ID enrollment pending), installs by
# cask work — Homebrew strips the quarantine bit — but a browser-downloaded
# DMG will be refused by Gatekeeper.
cask "jeliya" do
  version "TODO-app-version"
  sha256 "TODO-sha256-from-release-sidecar"

  # The DMG is universal (arm64 + x86_64) — one artifact for both.
  url "https://github.com/kortiene/jeliya/releases/download/TODO-release-tag/Jeliya-v#{version}-macos.dmg"
  name "Jeliya"
  desc "Peer-to-peer rooms for humans and agents — desktop app with bundled daemon"
  homepage "https://github.com/kortiene/jeliya"

  depends_on macos: ">= :monterey"

  app "Jeliya.app"

  zap trash: [
    # Shared with a Homebrew-installed jeliyad (deliberate: one identity and
    # room store per user) — zapping removes BOTH the app's and the daemon's
    # data, including the identity keypair. There is no recovery.
    "~/Library/Application Support/Jeliya",
    "~/Library/Containers/com.incubtek.jeliya",
  ]
end
