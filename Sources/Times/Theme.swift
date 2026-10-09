import AppKit
import SwiftUI

// V3ERA widget language: paper cards, black ink, hairlines, one yellow signal.
// Swap values here to re-theme the whole app.
extension Color {
    static func dynamic(_ light: UInt32, _ dark: UInt32, alpha: Double = 1, darkAlpha: Double? = nil) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? (darkAlpha ?? alpha) : alpha
            )
        })
    }
}

enum V3 {
    static let desk = Color.dynamic(0xECECE8, 0x060607)
    static let paper = Color.dynamic(0xFEFEFE, 0x111113)
    static let paperSoft = Color.dynamic(0xF6F6F3, 0x19191C)
    static let ink = Color.dynamic(0x0A0A0B, 0xF3F3F0)
    static let mute = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.48, darkAlpha: 0.52)
    static let whisper = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.28, darkAlpha: 0.30)
    static let line = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.11, darkAlpha: 0.10)
    static let lineStrong = Color.dynamic(0x0A0A0B, 0xF3F3F0, alpha: 0.23, darkAlpha: 0.22)
    /// Text on an ink-filled control.
    static let inverse = Color.dynamic(0xFEFEFE, 0x0A0A0B)
    static let signal = Color.dynamic(0xF2C500, 0xF5CC1A)
    static let signalWash = Color.dynamic(0xFFFBE6, 0x2A2508)
    static let done = Color.dynamic(0xD94B3D, 0xEE6A5C)
    static let positive = Color.dynamic(0x2D7A4A, 0x4FB27A)
    /// Always-dark face, like the V3ERA time widget's disc.
    static let night = Color(red: 0.035, green: 0.035, blue: 0.04)

    static let radiusCard: CGFloat = 7
    static let radiusControl: CGFloat = 2
}

enum V3Font {
    /// ui-monospace — tracked uppercase labels and small data.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Avenir Next Condensed — titles and the big numerals.
    static func condensed(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom("AvenirNextCondensed-\(weight.rawValue)", size: size)
    }
    enum Weight: String { case ultraLight = "UltraLight", regular = "Regular", medium = "Medium", demiBold = "DemiBold" }
}

extension View {
    /// V3ERA eyebrow: tiny tracked monospace caps.
    func eyebrow(_ color: Color = V3.whisper, size: CGFloat = 8) -> some View {
        font(V3Font.mono(size))
            .tracking(size * 0.26)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    func hairline(_ edges: Edge.Set, color: Color = V3.line) -> some View {
        overlay(alignment: .top) { if edges.contains(.top) { color.frame(height: 1) } }
            .overlay(alignment: .bottom) { if edges.contains(.bottom) { color.frame(height: 1) } }
            .overlay(alignment: .leading) { if edges.contains(.leading) { color.frame(width: 1) } }
            .overlay(alignment: .trailing) { if edges.contains(.trailing) { color.frame(width: 1) } }
    }
}

/// The V3ERA widget card: paper, strong hairline border, 7pt corners, soft drop shadow,
/// and a header with an eyebrow, a condensed title and a monospace status on the right.
struct WidgetCard<Accessory: View, Content: View>: View {
    let eyebrow: String
    let title: String
    var status: String = ""
    var statusColor: Color = V3.mute
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow).eyebrow(size: 7.5)
                    Text(title).font(V3Font.condensed(20)).foregroundStyle(V3.ink).lineLimit(1)
                }
                Spacer(minLength: 8)
                if !status.isEmpty { Text(status).eyebrow(statusColor, size: 7.5) }
                accessory
            }
            .padding(.horizontal, 17)
            .frame(minHeight: 60)
            .hairline(.bottom)
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(V3.paper)
        .clipShape(RoundedRectangle(cornerRadius: V3.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: V3.radiusCard).strokeBorder(V3.lineStrong))
        .shadow(color: .black.opacity(0.10), radius: 22, y: 12)
    }
}

extension WidgetCard where Accessory == EmptyView {
    init(eyebrow: String, title: String, status: String = "", statusColor: Color = V3.mute, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, title: title, status: status, statusColor: statusColor, accessory: { EmptyView() }, content: content)
    }
}

/// Square bordered button (V3ERA timer actions): paper fill, yellow on hover.
struct SquareButton: View {
    let symbol: String
    var help: String = ""
    var size: CGFloat = 30
    var filled = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(filled && !hover ? V3.inverse : V3.ink)
                .background(RoundedRectangle(cornerRadius: V3.radiusControl).fill(hover ? V3.signal : (filled ? V3.ink : V3.paper)))
                .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(hover || filled ? V3.ink : V3.lineStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// Wide monospace-caps button. `.ink` is the primary action, `.danger` stops things.
struct BarButton: View {
    enum Kind { case plain, ink, danger, signal }
    let title: String
    var kind: Kind = .plain
    var height: CGFloat = 38
    var disabled = false
    let action: () -> Void
    @State private var hover = false

    private var fill: Color {
        if disabled { return V3.paperSoft }
        switch kind {
        case .plain: return hover ? V3.ink : V3.paper
        case .ink: return hover ? V3.signal : V3.ink
        case .danger: return hover ? V3.ink : V3.done
        case .signal: return hover ? V3.ink : V3.signal
        }
    }

    private var text: Color {
        if disabled { return V3.whisper }
        switch kind {
        case .plain: return hover ? V3.inverse : V3.ink
        case .ink: return hover ? .black : V3.inverse
        case .danger: return hover ? V3.inverse : .white
        case .signal: return hover ? V3.inverse : .black
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(V3Font.mono(8.5, .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(fill)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// Small bordered chip, ink-filled when on (repeat days, presets, filters).
struct Chip: View {
    let title: String
    var on = false
    var width: CGFloat? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(V3Font.mono(8.5, .bold))
                .tracking(1)
                .foregroundStyle(on ? V3.inverse : V3.ink)
                .padding(.horizontal, width == nil ? 10 : 0)
                .frame(width: width, height: 26)
                .background(RoundedRectangle(cornerRadius: V3.radiusControl).fill(on ? V3.ink : (hover ? V3.signal : V3.paper)))
                .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(on || hover ? V3.ink : V3.lineStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Square-cornered switch: ink track with a yellow knob when on.
struct V3ToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 10) {
                configuration.label
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(configuration.isOn ? V3.ink : V3.paperSoft)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(configuration.isOn ? V3.ink : V3.lineStrong))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(configuration.isOn ? V3.signal : V3.paper)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(configuration.isOn ? .clear : V3.lineStrong))
                        .frame(width: 16, height: 16)
                        .padding(3)
                }
                .frame(width: 42, height: 22)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Plain text field in the V3ERA composer look: soft fill, hairline, monospace text.
struct FieldBox: View {
    let placeholder: String
    @Binding var text: String
    var mono = true
    var invalid = false
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(V3.whisper))
            .textFieldStyle(.plain)
            .font(mono ? V3Font.mono(11, .medium) : .system(size: 12))
            .foregroundStyle(V3.ink)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(V3.paperSoft)
            .overlay(alignment: .bottom) { if invalid { V3.done.frame(height: 2) } }
            .onSubmit(onSubmit)
    }
}

/// Moves the traffic lights so they sit centered in our taller top bar.
struct WindowChrome: NSViewRepresentable {
    static let barHeight: CGFloat = 56

    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ view: ChromeView, context: Context) { view.relayout() }

    final class ChromeView: NSView {
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
            ]
            tokens = names.map {
                NotificationCenter.default.addObserver(forName: $0, object: window, queue: .main) { [weak self] _ in
                    self?.relayout()
                }
            }
            relayout()
        }

        /// Switching light/dark makes AppKit rebuild the titlebar at its default size,
        /// so move it back once AppKit's own pass has finished.
        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            relayout()
            for delay in [0, 0.15] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.relayout() }
            }
        }

        func relayout() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let titlebar = close.superview, let container = titlebar.superview else { return }
            let height = WindowChrome.barHeight
            container.frame = NSRect(x: 0, y: window.frame.height - height, width: window.frame.width, height: height)
            titlebar.frame = container.bounds
            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            for (i, type) in buttons.enumerated() {
                guard let b = window.standardWindowButton(type) else { continue }
                b.setFrameOrigin(NSPoint(x: 20 + CGFloat(i) * 20, y: (height - b.frame.height) / 2))
            }
        }
    }
}
