import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Desktop v1 has no responsive/mobile layouts: this minimum replaces the
    // web client's 900px breakpoint (Phase 3 contract — 960x620).
    self.minSize = NSSize(width: 960, height: 620)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
