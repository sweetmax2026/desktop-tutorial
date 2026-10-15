import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerName as String] as? String)?.lowercased().contains("pangpang") == true {
    print(["title": window[kCGWindowName as String] ?? "", "bounds": window[kCGWindowBounds as String] ?? "", "onscreen": window[kCGWindowIsOnscreen as String] ?? "", "id": window[kCGWindowNumber as String] ?? ""])
}
