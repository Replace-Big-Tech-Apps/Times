import SwiftUI

struct ContentView: View {
    @Environment(TimesStore.self) private var store
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch store.tab {
                case .world: WorldClockView()
                case .alarms: AlarmsView()
                case .stopwatch: StopwatchView()
                case .timers: TimersView()
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(V3.desk)
        }
        .background(WindowChrome())
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: store.newItemTick) { if store.tab == .stopwatch, store.stopwatch.running { store.lapOrReset() } }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 84)
            HStack(spacing: 8) {
                Wordmark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Times").font(V3Font.condensed(17, .medium)).foregroundStyle(V3.ink)
                    Text("Clock desk").eyebrow(size: 6.5)
                }
            }
            .frame(width: 140, alignment: .leading)
            Spacer(minLength: 12)
            HStack(spacing: 0) {
                ForEach(Tab.allCases) { tab in
                    TabSegment(tab: tab, selected: store.tab == tab) {
                        withAnimation(.easeOut(duration: 0.15)) { store.tab = tab }
                    }
                }
            }
            .frame(maxWidth: 520, maxHeight: WindowChrome.barHeight)
            .layoutPriority(1)
            .hairline([.leading, .trailing])
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let clock = Fmt.clock(ctx.date, use24h: UserDefaults.standard.bool(forKey: "use24h"))
                    Text("\(clock.time) \(clock.suffix)").eyebrow(V3.mute, size: 8).monospacedDigit()
                }
                SquareButton(symbol: appearanceSymbol, help: "Appearance: \(appearance.capitalized)", size: 28) {
                    appearance = appearance == "system" ? "light" : appearance == "light" ? "dark" : "system"
                }
            }
            .frame(width: 140, alignment: .trailing)
            .padding(.trailing, 18)
        }
        .frame(height: WindowChrome.barHeight)
        .background(V3.paper)
        .hairline(.bottom, color: V3.lineStrong)
    }

    private var appearanceSymbol: String {
        switch appearance {
        case "light": "sun.max"
        case "dark": "moon"
        default: "circle.lefthalf.filled"
        }
    }
}

/// Numbered segment ("01 / WORLD CLOCK"); the selected one is ink with a yellow index.
struct TabSegment: View {
    let tab: Tab
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(String(format: "%02d", tab.rawValue + 1)).eyebrow(selected ? V3.signal : V3.whisper, size: 7)
                Text(tab.title).eyebrow(selected ? V3.inverse : V3.mute, size: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? V3.ink : (hover ? V3.paperSoft : V3.paper))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hairline(.trailing)
        .onHover { hover = $0 }
        .help("\(tab.title) (⌘\(tab.rawValue + 1))")
    }
}

/// Small app mark: the dot-matrix dial from the icon.
struct Wordmark: View {
    var body: some View {
        Canvas { ctx, size in
            let n = 9, step = size.width / CGFloat(n)
            for row in 0..<n {
                for col in 0..<n {
                    let x = (CGFloat(col) + 0.5) / CGFloat(n) - 0.5, y = (CGFloat(row) + 0.5) / CGFloat(n) - 0.5
                    let d = (x * x + y * y).squareRoot()
                    guard d < 0.5 else { continue }
                    let onHand = (abs(x) < 0.05 && y < 0 && y > -0.36) || (abs(y) < 0.05 && x > 0 && x < 0.26)
                    if onHand { continue }
                    let s = step * (0.3 + 0.45 * (1 - d * 1.6))
                    ctx.fill(Path(CGRect(x: CGFloat(col) * step + (step - s) / 2, y: CGFloat(row) * step + (step - s) / 2, width: s, height: s)),
                             with: .color(V3.ink.opacity(0.35 + 0.6 * (1 - d * 2))))
                }
            }
            ctx.fill(Path(ellipseIn: CGRect(x: size.width / 2 - 2.5, y: size.height / 2 - 2.5, width: 5, height: 5)), with: .color(V3.signal))
        }
        .frame(width: 26, height: 26)
    }
}
