import AppKit

extension HistoryPopupController {
    func origin(for screenPoint: NSPoint, windowSize: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(screenPoint, $0.frame, false) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            return screenPoint
        }

        let padding = HistoryPopupMetrics.screenEdgePadding
        let proposedX = min(screenPoint.x, visibleFrame.maxX - windowSize.width - padding)
        let proposedY = min(screenPoint.y - windowSize.height, visibleFrame.maxY - windowSize.height - padding)
        let clampedX = max(visibleFrame.minX + padding, proposedX)
        let clampedY = max(visibleFrame.minY + padding, proposedY)
        return NSPoint(x: clampedX, y: clampedY)
    }
}
