import SwiftUI

/// Menu bar item: the soonest running timer, else the stopwatch, else a clock glyph.
/// Driven by the store's once-a-second `menuTitle`; a TimelineView here loops the status item.
struct MenuBarLabel: View {
    @Environment(TimesStore.self) private var store

    var body: some View {
        if !store.ringing.isEmpty {
            Image(systemName: "alarm.waves.left.and.right.fill")
        } else if let title = store.menuTitle {
            Text(title).monospacedDigit()
        } else {
            Image(systemName: "clock")
        }
    }
}

struct MenuBarPanel: View {
    @Environment(TimesStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @AppStorage("use24h") private var use24h = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let now = ctx.date
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    let c = Fmt.clock(now, use24h: use24h, seconds: true)
                    Text(c.time).font(V3Font.condensed(44, .ultraLight)).monospacedDigit().foregroundStyle(V3.ink)
                    Text(c.suffix).eyebrow(V3.mute, size: 8)
                    Spacer()
                    Wordmark()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Text(Fmt.date(now)).eyebrow(V3.mute, size: 7).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    .hairline(.bottom)

                if let (alarm, date) = store.nextAlarm(after: now) {
                    let c = Fmt.clock(date, use24h: use24h)
                    line("Next alarm", "\(c.time) \(c.suffix)", detail: "\(alarm.title) · \(Fmt.until(date, from: now))").hairline(.bottom)
                }
                ForEach(store.timers) { t in
                    HStack {
                        line("Timer", t.state == .done ? "DONE" : Fmt.countdown(t.left(at: now)), detail: t.title + (t.state == .paused ? " · paused" : ""))
                        if t.state != .done {
                            SquareButton(symbol: t.state == .running ? "pause.fill" : "play.fill", size: 24) { store.toggle(t) }
                        }
                        SquareButton(symbol: "xmark", size: 24) { store.cancel(t) }.padding(.trailing, 14)
                    }
                    .hairline(.bottom)
                }
                if !store.stopwatch.isReset {
                    HStack {
                        line("Stopwatch", Fmt.stopwatch(store.stopwatch.elapsed(at: now)), detail: store.stopwatch.running ? "Running" : "Stopped")
                        SquareButton(symbol: store.stopwatch.running ? "pause.fill" : "play.fill", size: 24) { store.startStop() }
                            .padding(.trailing, 14)
                    }
                    .hairline(.bottom)
                }
                ForEach(store.cities.prefix(4)) { city in
                    let c = Fmt.clock(now, zone: city.timeZone, use24h: use24h)
                    line(city.name, "\(c.time) \(c.suffix)", detail: Fmt.offset(city.timeZone, at: now)).hairline(.bottom)
                }
                HStack(spacing: 1) {
                    BarButton(title: "Open Times", kind: .ink, height: 36) {
                        openWindow(id: "main")
                        NSApp.activate()
                    }
                    BarButton(title: "Quit", height: 36) { NSApp.terminate(nil) }
                }
                .background(V3.line)
            }
            .frame(width: 290)
            .background(V3.paper)
        }
    }

    private func line(_ title: String, _ value: String, detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).eyebrow(size: 6.5)
                Text(detail).font(V3Font.mono(9, .medium)).foregroundStyle(V3.mute).lineLimit(1)
            }
            Spacer()
            Text(value).font(V3Font.condensed(22)).monospacedDigit().foregroundStyle(V3.ink)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }
}
