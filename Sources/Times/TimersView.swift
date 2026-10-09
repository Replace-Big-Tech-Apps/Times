import SwiftUI

struct TimersView: View {
    @Environment(TimesStore.self) private var store
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""
    @State private var sound = Sounds.timerDefault
    @State private var quick = ""
    @State private var quickInvalid = false
    @FocusState private var quickFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            composer.frame(width: 370)
            VStack(spacing: 18) {
                activeCard
                recentsCard.frame(height: 210)
            }
        }
        .onChange(of: store.newItemTick) { if store.tab == .timers { quickFocused = true } }
    }

    private var picked: TimeInterval { TimeInterval(hours * 3600 + minutes * 60 + seconds) }

    private var composer: some View {
        WidgetCard(eyebrow: "Countdown", title: "New timer", status: picked > 0 ? Fmt.durationName(picked) : "Set a time") {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    NumeralWheel(value: $hours, range: 0...23, size: 54, caption: "Hr")
                    Text(":").font(V3Font.condensed(46, .ultraLight)).foregroundStyle(V3.whisper).padding(.bottom, 18)
                    NumeralWheel(value: $minutes, range: 0...59, size: 54, caption: "Min")
                    Text(":").font(V3Font.condensed(46, .ultraLight)).foregroundStyle(V3.whisper).padding(.bottom, 18)
                    NumeralWheel(value: $seconds, range: 0...59, size: 54, caption: "Sec")
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(V3.paperSoft)
                .hairline(.bottom)

                row("Label") {
                    FieldBox(placeholder: "Timer", text: $label, mono: false)
                        .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(V3.line))
                }
                row("When done") { SoundMenu(sound: $sound) }

                BarButton(title: "Start", kind: .ink, height: 46, disabled: picked < 1) {
                    store.startTimer(duration: picked, label: label.trimmingCharacters(in: .whitespaces), sound: sound)
                    label = ""
                }
                .hairline(.bottom)

                Text("Presets").eyebrow(size: 7).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 17).padding(.top, 14).padding(.bottom, 8)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 4), spacing: 1) {
                    ForEach([("1M", 60.0), ("3M", 180), ("5M", 300), ("10M", 600), ("15M", 900), ("25M", 1500), ("30M", 1800), ("1H", 3600)], id: \.0) { preset in
                        BarButton(title: preset.0, height: 36) { store.startTimer(duration: preset.1, label: "", sound: sound) }
                    }
                }
                .background(V3.line)
                .hairline([.top, .bottom])

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    TextField("", text: $quick, prompt: Text("7:30 · 20m · 1h 15m").foregroundStyle(V3.whisper))
                        .textFieldStyle(.plain)
                        .font(V3Font.mono(11, .medium))
                        .foregroundStyle(V3.ink)
                        .focused($quickFocused)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(V3.paperSoft)
                        .overlay(alignment: .bottom) { if quickInvalid { V3.done.frame(height: 2) } }
                        .onSubmit(startQuick)
                        .onChange(of: quick) { quickInvalid = false }
                    BarButton(title: "Go", kind: .ink, height: 44, action: startQuick).frame(width: 74)
                }
                .hairline(.top)
            }
        }
    }

    private func startQuick() {
        let t = Fmt.parseDuration(quick)
        guard t >= 1 else { quickInvalid = true; return }
        store.startTimer(duration: t, label: label.trimmingCharacters(in: .whitespaces), sound: sound)
        quick = ""
        label = ""
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 12) {
            Text(title).eyebrow(size: 7.5).frame(width: 74, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 10)
        .hairline(.bottom)
    }

    private var activeCard: some View {
        let running = store.timers.filter { $0.state == .running }.count
        let done = store.timers.filter { $0.state == .done }.count
        let status = done > 0 ? "\(done) done" : running > 0 ? "\(running) running" : store.timers.isEmpty ? "Idle" : "Paused"
        return WidgetCard(eyebrow: "Active", title: "Timers", status: status, statusColor: done > 0 ? V3.done : V3.mute) {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                if store.timers.isEmpty {
                    EmptyNote(text: "No timers yet. Pick a preset or set a time.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.timers) { TimerRow(timer: $0, now: ctx.date) }
                        }
                    }
                }
            }
        }
    }

    private var recentsCard: some View {
        WidgetCard(eyebrow: "History", title: "Recents", status: "\(store.recents.count)") {
            if store.recents.isEmpty {
                EmptyNote(text: "Timers you start show up here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.recents) { recent in
                            HStack(spacing: 12) {
                                Text(Fmt.countdown(recent.duration)).font(V3Font.condensed(26, .ultraLight)).monospacedDigit().foregroundStyle(V3.ink)
                                    .frame(width: 96, alignment: .leading)
                                Text(recent.label.isEmpty ? Fmt.durationName(recent.duration) : recent.label).eyebrow(V3.mute, size: 7.5).lineLimit(1)
                                Spacer()
                                SquareButton(symbol: "xmark", help: "Remove from recents", size: 26) { store.removeRecent(recent) }
                                SquareButton(symbol: "play.fill", help: "Start again", size: 26, filled: true) {
                                    store.startTimer(duration: recent.duration, label: recent.label, sound: recent.sound)
                                }
                            }
                            .padding(.horizontal, 17)
                            .frame(height: 48)
                            .hairline(.bottom)
                        }
                    }
                }
            }
        }
    }
}

/// V3ERA timer row: label, big remaining time, square actions, a yellow progress rail.
struct TimerRow: View {
    @Environment(TimesStore.self) private var store
    let timer: Countdown
    let now: Date

    var body: some View {
        let done = timer.state == .done
        HStack(spacing: 14) {
            ProgressRing(progress: timer.progress(at: now), paused: timer.state == .paused)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 6) {
                Text(timer.title + (timer.state == .paused ? " · paused" : "")).eyebrow(done ? .white.opacity(0.55) : V3.mute, size: 7.5).lineLimit(1)
                Text(done ? "DONE" : Fmt.countdown(timer.left(at: now)))
                    .font(V3Font.condensed(44, .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(done ? V3.signal : timer.state == .paused ? V3.whisper : V3.ink)
            }
            Spacer()
            if !done, let end = timer.endsAt {
                let c = Fmt.clock(end, use24h: UserDefaults.standard.bool(forKey: "use24h"))
                HStack(spacing: 4) {
                    Image(systemName: "bell").font(.system(size: 8))
                    Text("\(c.time) \(c.suffix)").font(V3Font.mono(8.5, .semibold))
                }
                .foregroundStyle(V3.mute)
            }
            HStack(spacing: 5) {
                if done {
                    SquareButton(symbol: "arrow.clockwise", help: "Restart") {
                        let t = timer
                        store.cancel(t)
                        store.startTimer(duration: t.duration, label: t.label, sound: t.sound)
                    }
                } else {
                    SquareButton(symbol: timer.state == .running ? "pause.fill" : "play.fill",
                                 help: timer.state == .running ? "Pause" : "Resume") { store.toggle(timer) }
                }
                SquareButton(symbol: "plus", help: "Add one minute") { store.extend(timer, by: 60) }
                SquareButton(symbol: "xmark", help: "Cancel timer") { store.cancel(timer) }
            }
        }
        .padding(.leading, 17)
        .padding(.trailing, 14)
        .frame(height: 84)
        .background(done ? V3.night : V3.paper)
        .overlay(alignment: .bottom) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    V3.line
                    (timer.state == .paused ? V3.whisper : V3.signal).frame(width: g.size.width * timer.progress(at: now))
                }
            }
            .frame(height: 3)
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    var paused = false

    var body: some View {
        ZStack {
            Circle().stroke(V3.line, lineWidth: 3)
            Circle().trim(from: 0, to: progress)
                .stroke(paused ? V3.whisper : V3.signal, style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            Circle().fill(paused ? V3.whisper : V3.ink).frame(width: 5, height: 5)
        }
    }
}
