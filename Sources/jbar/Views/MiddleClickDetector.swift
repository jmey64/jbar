import SwiftUI
import AppKit

public struct MiddleClickDetector: NSViewRepresentable {
    var onMiddleClick: () -> Void

    public init(onMiddleClick: @escaping () -> Void) {
        self.onMiddleClick = onMiddleClick
    }

    public func makeNSView(context: Context) -> MiddleClickView {
        let view = MiddleClickView()
        view.onMiddleClick = onMiddleClick
        return view
    }

    public func updateNSView(_ nsView: MiddleClickView, context: Context) {
        nsView.onMiddleClick = onMiddleClick
    }

    public final class MiddleClickView: NSView {
        var onMiddleClick: (() -> Void)?
        private var monitor: Any?

        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                if monitor == nil {
                    monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                        guard let self = self, event.buttonNumber == 2 else { return event }
                        let locationInWindow = event.locationInWindow
                        let locationInView = self.convert(locationInWindow, from: nil)
                        if self.bounds.contains(locationInView) {
                            self.onMiddleClick?()
                            return nil
                        }
                        return event
                    }
                }
            } else {
                if let m = monitor {
                    NSEvent.removeMonitor(m)
                    monitor = nil
                }
            }
        }

        deinit {
            if let m = monitor {
                NSEvent.removeMonitor(m)
            }
        }
    }
}

public extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        self.background(MiddleClickDetector(onMiddleClick: action))
    }
}
