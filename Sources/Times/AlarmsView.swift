import SwiftUI

struct AlarmsView: View {
    @Environment(TimesStore.self) private var store
    @AppStorage("use24h") private var use24h = false
    @State private var editing: Alarm?
    @State private var isNew = false

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            listCard
            nextCard.frame(width: 320)
        }
        .sheet(item: $editing) { alarm in
            AlarmEditor(alarm: alarm, isNew: isNew).environment(store)
        }
        .onChange(of: store.newItemTick) { if store.tab == .alarms { add() } }
    }

    private func add() {
        let next = Calendar.current.dateComponents([.hour, .minute], from: .now.addingTimeInterval(3600))
        isNew = true
        editing = Alarm(hour: next.hour ?? 7, minute: 0)
    }

    private var listCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let on = store.alarms.filter(\.enabled).count
            WidgetCard(eyebrow: "Wake & remind", title: "Alarms", status: store.alarms.isEmpty ? "Idle" : "\(on) on") {
                SquareButton(symbol: "plus", help: "New alarm (⌘N)", size: 26) { add() }
            } content: {
                if store.alarms.isEmpty {
                    EmptyNote(text: "No alarms. Press + to set one.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.alarms) { alarm in
                                AlarmRow(alarm: alarm, now: ctx.date, use24h: use24h) {
                                    isNew = false
                                    editing = alarm
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// The V3ERA time face: a black disc on paper with the next ring in white.
    private var nextCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let next = store.nextAlarm(after: ctx.date)
            WidgetCard(eyebrow: "Next alarm", title: next?.0.title ?? "None set",
                       status: next.map { Fmt.until($0.1, from: ctx.date) } ?? "Off", statusColor: next == nil ? V3.whisper : V3.mute) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle().fill(V3.night)
                        Circle().inset(by: 26).fill(Color(white: 0.09))
                        if let (_, date) = next {
                            let c = Fmt.clock(date, use24h: use24h)
                            VStack(spacing: 12) {
                                HStack(alignment: .top, spacing: 3) {
                                    Text(c.time).font(V3Font.condensed(62, .ultraLight)).monospacedDigit().foregroundStyle(.white)
                                    Text(c.suffix).font(V3Font.mono(9, .semibold)).foregroundStyle(V3.signal).padding(.top, 10)
                                }
                                Text(Fmt.date(date, zone: .current, "EEEEdMMMM")).eyebrow(.white.opacity(0.55), size: 7)
                            }
                        } else {
                            Text("--:--").font(V3Font.condensed(62, .ultraLight)).foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.vertical, 20)
                    Spacer(minLength: 0)
                    if let (alarm, _) = next {
                        HStack(spacing: 0) {
                            stat("Repeat", alarm.repeatText)
                            stat("Sound", alarm.sound)
                            stat("Snooze", alarm.snoozedUntil != nil ? "Snoozed" : alarm.snooze ? "\(Int(Prefs.snoozeMinutes)) min" : "Off")
                        }
                        .hairline(.top)
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow(size: 7)
            Text(value).font(V3Font.mono(10, .medium)).foregroundStyle(V3.ink).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .hairline(.trailing)
    }
}

struct AlarmRow: View {
    @Environment(TimesStore.self) private var store
    let alarm: Alarm
    let now: Date
    let use24h: Bool
    let edit: () -> Void
    @State private var hover = false

    var body: some View {
        let c = Fmt.clock(hour: alarm.hour, minute: alarm.minute, use24h: use24h)
        let tone = alarm.enabled ? V3.ink : V3.whisper
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(c.time).font(V3Font.condensed(50, .ultraLight)).monospacedDigit().foregroundStyle(tone)
                    if !c.suffix.isEmpty { Text(c.suffix).eyebrow(alarm.enabled ? V3.mute : V3.whisper, size: 9) }
                }
                HStack(spacing: 8) {
                    Text(alarm.title).eyebrow(alarm.enabled ? V3.ink : V3.whisper, size: 7.5)
                    Text("·").eyebrow(size: 7.5)
                    Text(alarm.repeatText).eyebrow(alarm.enabled ? V3.mute : V3.whisper, size: 7.5)
                    if let s = alarm.snoozedUntil, s > now {
                        let sc = Fmt.clock(s, use24h: use24h)
                        Text("Snoozed · \(sc.time) \(sc.suffix)").eyebrow(.black, size: 6.5)
                            .padding(.horizontal, 5).padding(.vertical, 3).background(V3.signal)
                    }
                }
            }
            Spacer()
            if hover {
                SquareButton(symbol: "trash", help: "Delete alarm", size: 28) { store.deleteAlarm(alarm) }
                    .transition(.opacity)
            }
            Toggle("", isOn: Binding(get: { alarm.enabled }, set: { store.setEnabled(alarm, $0) }))
                .toggleStyle(V3ToggleStyle())
                .labelsHidden()
        }
        .padding(.horizontal, 17)
        .frame(height: 104)
        .background(hover ? V3.paperSoft : V3.paper)
        .hairline(.bottom)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .contextMenu {
            Button("Edit…", action: edit)
            Button(alarm.enabled ? "Turn Off" : "Turn On") { store.setEnabled(alarm, !alarm.enabled) }
            Divider()
            Button("Delete", role: .destructive) { store.deleteAlarm(alarm) }
        }
    }
}

struct AlarmEditor: View {
    @Environment(TimesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("use24h") private var use24h = false
    @State var alarm: Alarm
    let isNew: Bool

    var body: some View {
        WidgetCard(eyebrow: isNew ? "New alarm" : "Edit alarm", title: alarm.title,
                   status: alarm.nextFire(after: .now).map { Fmt.until($0, from: .now) } ?? "") {
            VStack(spacing: 0) {
                timePicker
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(V3.paperSoft)
                    .hairline(.bottom)
                section("Repeat") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 5) {
                            let symbols = Calendar.current.veryShortWeekdaySymbols
                            ForEach(Alarm.weekOrder, id: \.self) { day in
                                Chip(title: symbols[day - 1], on: alarm.days.contains(day), width: 30) {
                                    if alarm.days.contains(day) { alarm.days.remove(day) } else { alarm.days.insert(day) }
                                }
                            }
                        }
                        HStack(spacing: 5) {
                            Chip(title: "ONCE", on: alarm.days.isEmpty) { alarm.days = [] }
                            Chip(title: "WEEKDAYS", on: alarm.days == [2, 3, 4, 5, 6]) { alarm.days = [2, 3, 4, 5, 6] }
                            Chip(title: "WEEKENDS", on: alarm.days == [1, 7]) { alarm.days = [1, 7] }
                            Chip(title: "DAILY", on: alarm.days.count == 7) { alarm.days = Set(1...7) }
                        }
                    }
                }
                section("Label") {
                    FieldBox(placeholder: "Alarm", text: $alarm.label, mono: false)
                        .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(V3.line))
                }
                section("Sound") { SoundMenu(sound: $alarm.sound) }
                section("Snooze") {
                    Toggle("", isOn: $alarm.snooze).toggleStyle(V3ToggleStyle()).labelsHidden()
                }
                Spacer(minLength: 0)
                HStack(spacing: 1) {
                    if !isNew {
                        BarButton(title: "Delete", kind: .danger, height: 44) { store.deleteAlarm(alarm); dismiss() }
                    }
                    BarButton(title: "Cancel", height: 44) { dismiss() }
                    BarButton(title: "Save", kind: .ink, height: 44) { store.upsert(alarm); dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
                .background(V3.line)
                .hairline(.top)
            }
        }
        .frame(width: 440, height: 560)
        .padding(1)
        .background(V3.desk)
        .onExitCommand { dismiss() }
    }

    private var timePicker: some View {
        HStack(alignment: .center, spacing: 10) {
            if use24h {
                NumeralWheel(value: $alarm.hour, range: 0...23, caption: "Hour")
            } else {
                NumeralWheel(value: Binding(get: { alarm.hour % 12 == 0 ? 12 : alarm.hour % 12 },
                                            set: { alarm.hour = ($0 % 12) + (alarm.hour >= 12 ? 12 : 0) }),
                             range: 1...12, pad: 1, caption: "Hour")
            }
            Text(":").font(V3Font.condensed(56, .ultraLight)).foregroundStyle(V3.whisper).padding(.bottom, 18)
            NumeralWheel(value: $alarm.minute, range: 0...59, caption: "Minute")
            if !use24h {
                VStack(spacing: 5) {
                    Chip(title: Calendar.current.amSymbol, on: alarm.hour < 12, width: 44) { if alarm.hour >= 12 { alarm.hour -= 12 } }
                    Chip(title: Calendar.current.pmSymbol, on: alarm.hour >= 12, width: 44) { if alarm.hour < 12 { alarm.hour += 12 } }
                }
                .padding(.leading, 8)
                .padding(.bottom, 18)
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 12) {
            Text(title).eyebrow(size: 7.5).frame(width: 64, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 10)
        .hairline(.bottom)
    }
}

/// Big condensed numeral with chevrons; also takes ↑/↓, typed digits and vertical drags.
struct NumeralWheel: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var pad = 2
    var size: CGFloat = 64
    var caption = ""
    @FocusState private var focused: Bool
    @State private var typed = ""
    @State private var dragStart: Int?

    var body: some View {
        VStack(spacing: 2) {
            chevron("chevron.up", 1)
            Text(String(format: "%0\(pad)d", value))
                .font(V3Font.condensed(size, .ultraLight))
                .monospacedDigit()
                .foregroundStyle(V3.ink)
                .frame(minWidth: size * 0.95)
                .padding(.horizontal, 6)
                .overlay(alignment: .bottom) { (focused ? V3.signal : .clear).frame(height: 2) }
                .contentShape(Rectangle())
                .focusable()
                .focusEffectDisabled()
                .focused($focused)
                .onTapGesture { focused = true }
                .onKeyPress(.upArrow) { step(1); return .handled }
                .onKeyPress(.downArrow) { step(-1); return .handled }
                .onKeyPress(characters: .decimalDigits) { press in
                    typed += press.characters
                    if typed.count > 2 || !(Int(typed).map(range.contains) ?? false) { typed = press.characters }
                    if let n = Int(typed), range.contains(n) { value = n }
                    return .handled
                }
                .onChange(of: focused) { typed = "" }
                .gesture(DragGesture(minimumDistance: 4).onChanged { g in
                    if dragStart == nil { dragStart = value }
                    set((dragStart ?? value) - Int(g.translation.height / 12))
                }.onEnded { _ in dragStart = nil })
            chevron("chevron.down", -1)
            if !caption.isEmpty { Text(caption).eyebrow(size: 7) }
        }
    }

    private func chevron(_ symbol: String, _ delta: Int) -> some View {
        Button { step(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(V3.mute)
                .frame(width: 44, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func step(_ delta: Int) { set(value + delta) }

    private func set(_ n: Int) {
        let span = range.upperBound - range.lowerBound + 1
        value = ((n - range.lowerBound) % span + span) % span + range.lowerBound
    }
}

struct SoundMenu: View {
    @Environment(TimesStore.self) private var store
    @Binding var sound: String

    var body: some View {
        Menu {
            ForEach(Sounds.all, id: \.self) { name in
                Button { sound = name; store.preview(name) } label: {
                    if name == sound { Label(name, systemImage: "checkmark") } else { Text(name) }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2").font(.system(size: 10))
                Text(sound).font(V3Font.mono(10.5, .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
            }
            .foregroundStyle(V3.ink)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: V3.radiusControl).fill(V3.paper))
            .overlay(RoundedRectangle(cornerRadius: V3.radiusControl).strokeBorder(V3.lineStrong))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
