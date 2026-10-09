import SwiftUI

struct StopwatchView: View {
    @Environment(TimesStore.self) private var store
    @AppStorage("stopwatchAnalog") private var analog = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            faceCard
            lapsCard.frame(width: 340)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.space) { store.startStop(); return .handled }
        .onKeyPress("l") { if store.stopwatch.running { store.lapOrReset() }; return .handled }
        .onKeyPress("r") { if !store.stopwatch.running { store.lapOrReset() }; return .handled }
    }

    private var status: String {
        store.stopwatch.running ? "Running" : store.stopwatch.isReset ? "Ready" : "Stopped"
    }

    private var faceCard: some View {
        WidgetCard(eyebrow: "Chronograph", title: "Stopwatch", status: status,
                   statusColor: store.stopwatch.running ? V3.ink : V3.mute) {
            HStack(spacing: 5) {
                Chip(title: "DIGITAL", on: !analog) { analog = false }
                Chip(title: "ANALOG", on: analog) { analog = true }
            }
        } content: {
            VStack(spacing: 0) {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !store.stopwatch.running)) { ctx in
                    let t = store.stopwatch.elapsed(at: ctx.date)
                    let lapStart = store.stopwatch.marks.last ?? 0
                    Group {
                        if analog {
                            StopwatchDial(total: t, lap: t - lapStart, hasLaps: !store.stopwatch.marks.isEmpty)
                                .frame(maxWidth: 380, maxHeight: 380)
                                .padding(24)
                        } else {
                            VStack(spacing: 14) {
                                Text(Fmt.stopwatch(t))
                                    .font(V3Font.condensed(118, .ultraLight))
                                    .monospacedDigit()
                                    .foregroundStyle(V3.ink)
                                    .minimumScaleFactor(0.4)
                                    .lineLimit(1)
                                Text(store.stopwatch.marks.isEmpty ? "Space to start · L to lap · R to reset" : "Lap \(store.stopwatch.marks.count + 1) · \(Fmt.stopwatch(t - lapStart))")
                                    .eyebrow(V3.mute, size: 8)
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: 1) {
                    BarButton(title: store.stopwatch.running ? "Lap" : "Reset", height: 52,
                              disabled: store.stopwatch.isReset) { store.lapOrReset() }
                    BarButton(title: store.stopwatch.running ? "Stop" : "Start",
                              kind: store.stopwatch.running ? .danger : .ink, height: 52) { store.startStop() }
                }
                .background(V3.line)
                .hairline(.top)
            }
        }
    }

    private var lapsCard: some View {
        let laps = store.stopwatch.laps
        // Best and worst only mean something once there are two laps to compare.
        let best = laps.count >= 2 ? laps.indices.min { laps[$0] < laps[$1] } : nil
        let worst = laps.count >= 2 ? laps.indices.max { laps[$0] < laps[$1] } : nil
        return WidgetCard(eyebrow: "Splits", title: "Laps", status: laps.isEmpty ? "None" : "\(laps.count) done") {
            TimelineView(.animation(minimumInterval: 1 / 15, paused: !store.stopwatch.running)) { ctx in
                if store.stopwatch.isReset {
                    EmptyNote(text: "Laps appear here while the stopwatch runs.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            lapRow(laps.count + 1, store.stopwatch.elapsed(at: ctx.date) - (store.stopwatch.marks.last ?? 0), tone: V3.ink, tag: "Now")
                            ForEach(laps.indices.reversed(), id: \.self) { i in
                                lapRow(i + 1, laps[i], tone: i == best ? V3.positive : i == worst ? V3.done : V3.ink,
                                       tag: i == best ? "Best" : i == worst ? "Worst" : "")
                            }
                        }
                    }
                }
            }
        }
    }

    private func lapRow(_ n: Int, _ t: TimeInterval, tone: Color, tag: String) -> some View {
        HStack {
            Text(String(format: "Lap %02d", n)).eyebrow(V3.mute, size: 8)
            if !tag.isEmpty { Text(tag).eyebrow(tone, size: 6.5) }
            Spacer()
            Text(Fmt.stopwatch(t)).font(V3Font.condensed(24)).monospacedDigit().foregroundStyle(tone)
        }
        .padding(.horizontal, 17)
        .frame(height: 46)
        .hairline(.bottom)
    }
}

/// Apple-style analog stopwatch: 60-second dial, a 30-minute subdial, and a lap hand.
struct StopwatchDial: View {
    let total: TimeInterval
    let lap: TimeInterval
    let hasLaps: Bool

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let r = side / 2, c = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: side, height: side)), with: .color(V3.night))

            for i in 0..<240 {
                let a = Double(i) / 240 * 2 * .pi
                let major = i % 20 == 0, mid = i % 4 == 0
                var p = Path()
                p.move(to: pt(c, a, r * (major ? 0.84 : mid ? 0.88 : 0.91)))
                p.addLine(to: pt(c, a, r * 0.95))
                ctx.stroke(p, with: .color(.white.opacity(major ? 0.9 : mid ? 0.55 : 0.22)), lineWidth: major ? 2 : 1)
            }
            for i in stride(from: 5, through: 60, by: 5) {
                let a = Double(i) / 60 * 2 * .pi
                let label = ctx.resolve(Text("\(i)").font(V3Font.condensed(side * 0.055)).foregroundStyle(.white))
                ctx.draw(label, at: pt(c, a, r * 0.73))
            }

            // 30-minute subdial above center.
            let sc = CGPoint(x: c.x, y: c.y - r * 0.33), sr = r * 0.2
            for i in 0..<30 {
                let a = Double(i) / 30 * 2 * .pi, major = i % 5 == 0
                var p = Path()
                p.move(to: pt(sc, a, sr * (major ? 0.72 : 0.84)))
                p.addLine(to: pt(sc, a, sr * 0.96))
                ctx.stroke(p, with: .color(.white.opacity(major ? 0.8 : 0.35)), lineWidth: 1)
            }
            hand(&ctx, sc, (total / 60).truncatingRemainder(dividingBy: 30) / 30 * 2 * .pi, sr * 0.9, 0, 1.6, V3.signal)
            ctx.fill(Path(ellipseIn: CGRect(x: sc.x - 2.5, y: sc.y - 2.5, width: 5, height: 5)), with: .color(V3.signal))

            let digits = ctx.resolve(Text(Fmt.stopwatch(total)).font(V3Font.condensed(side * 0.075)).monospacedDigit().foregroundStyle(.white))
            ctx.draw(digits, at: CGPoint(x: c.x, y: c.y + r * 0.35))

            if hasLaps { hand(&ctx, c, lap.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi, r * 0.9, r * 0.15, 1.6, Color(red: 0.35, green: 0.62, blue: 1)) }
            hand(&ctx, c, total.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi, r * 0.92, r * 0.18, 2, V3.signal)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)), with: .color(V3.signal))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(V3.night))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func hand(_ ctx: inout GraphicsContext, _ c: CGPoint, _ a: Double, _ len: Double, _ tail: Double, _ w: CGFloat, _ color: Color) {
        var p = Path()
        p.move(to: pt(c, a + .pi, tail))
        p.addLine(to: pt(c, a, len))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    private func pt(_ c: CGPoint, _ a: Double, _ radius: Double) -> CGPoint {
        CGPoint(x: c.x + sin(a) * radius, y: c.y - cos(a) * radius)
    }
}
