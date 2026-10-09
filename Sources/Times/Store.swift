import AppKit
import Observation

/// Owns every clock, alarm, timer and the stopwatch. One 4 Hz ticker drives firing;
/// views draw from their own TimelineViews so they never wait on the store.
@MainActor
@Observable
final class TimesStore {
    static let shared = TimesStore()

    var tab: Tab = .world { didSet { save() } }
    var cities: [City] = [] { didSet { save() } }
    var alarms: [Alarm] = [] { didSet { save(); Notifier.sync(self) } }
    var timers: [Countdown] = [] { didSet { save(); Notifier.sync(self) } }
    var recents: [RecentTimer] = [] { didSet { save() } }
    var stopwatch = Stopwatch() { didSet { save() } }

    private(set) var ringing: [Ringing] = []
    /// Menu bar text: soonest running timer, else a running stopwatch. Only reassigned when it changes.
    private(set) var menuTitle: String?
    /// Bumped by ⌘N; the visible tab opens its "add" flow.
    var newItemTick = 0

    @ObservationIgnored private var lastCheck = Date.now
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var loading = true
    @ObservationIgnored private let player = SoundPlayer()
    private static let key = "times.state.v1"

    private init() {
        let snap = UserDefaults.standard.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        if let snap {
            cities = snap.cities; alarms = snap.alarms; timers = snap.timers
            recents = snap.recents; stopwatch = snap.stopwatch; tab = snap.tab
            catchUp(since: snap.lastRun ?? .now)
        } else {
            var seen = Set<String>()
            cities = ([Places.local] + ["Cupertino", "New York", "London", "Tokyo"].compactMap(Places.named))
                .filter { seen.insert($0.zone).inserted }
                .map(City.init)
            alarms = [Alarm(hour: 7, minute: 0, days: [2, 3, 4, 5, 6], enabled: false)]
        }
        loading = false
        save()
    }

    func start() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 0.25, repeats: true) { _ in MainActor.assumeIsolated { TimesStore.shared.tick() } }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
        Notifier.sync(self)
    }

    func save() {
        guard !loading else { return }
        let snap = Snapshot(cities: cities, alarms: alarms, timers: timers, recents: recents, stopwatch: stopwatch, lastRun: .now, tab: tab)
        if let data = try? JSONEncoder().encode(snap) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    // MARK: Engine

    /// Resolve what happened while the app was closed: rings that are only minutes old still
    /// ring, older one-shot alarms count as fired (the notification covered them).
    private func catchUp(since last: Date) {
        let now = Date.now, grace: TimeInterval = 10 * 60
        for i in alarms.indices where alarms[i].enabled {
            if let s = alarms[i].snoozedUntil, s <= now { alarms[i].snoozedUntil = nil }
            if alarms[i].days.isEmpty, let fire = alarms[i].nextFire(after: last), fire <= now, now.timeIntervalSince(fire) > grace {
                alarms[i].enabled = false
            }
        }
        timers.removeAll { $0.state == .done || ($0.state == .running && ($0.endsAt ?? now) < now.addingTimeInterval(-grace)) }
        lastCheck = min(max(last, now.addingTimeInterval(-grace)), now)
    }

    private func tick() {
        let now = Date.now
        for i in timers.indices where timers[i].state == .running && (timers[i].endsAt ?? now) <= now {
            timers[i].state = .done
            timers[i].remaining = 0
            ring(Ringing(id: timers[i].id, kind: .timer, title: timers[i].title, sound: timers[i].sound, canSnooze: false, at: now))
        }
        for i in alarms.indices where alarms[i].enabled {
            let alarm = alarms[i]
            if let s = alarm.snoozedUntil {
                if s <= now {
                    alarms[i].snoozedUntil = nil
                    ring(Ringing(id: alarm.id, kind: .alarm, title: alarm.title, sound: alarm.sound, canSnooze: alarm.snooze, at: now))
                }
            } else if let fire = alarm.nextFire(after: lastCheck), fire <= now {
                if alarm.days.isEmpty { alarms[i].enabled = false }
                ring(Ringing(id: alarm.id, kind: .alarm, title: alarm.title, sound: alarm.sound, canSnooze: alarm.snooze, at: now))
            }
        }
        lastCheck = now

        let title: String? = if let t = timers.filter({ $0.state == .running }).min(by: { $0.left(at: now) < $1.left(at: now) }) {
            "⏲ " + Fmt.countdown(t.left(at: now))
        } else if stopwatch.running {
            "⏱ " + Fmt.stopwatch(stopwatch.elapsed(at: now)).dropLast(3)
        } else { nil }
        if title != menuTitle { menuTitle = title }
    }

    private func ring(_ r: Ringing) {
        ringing.removeAll { $0.id == r.id }
        ringing.append(r)
        player.loop(r.sound)
        RingingPanel.shared.show()
    }

    func dismiss(_ r: Ringing, snooze: Bool = false) {
        ringing.removeAll { $0.id == r.id }
        switch r.kind {
        case .alarm:
            if snooze, let i = alarms.firstIndex(where: { $0.id == r.id }) {
                alarms[i].enabled = true
                alarms[i].snoozedUntil = .now.addingTimeInterval(Prefs.snoozeMinutes * 60)
            }
        case .timer:
            timers.removeAll { $0.id == r.id }
        }
        if let next = ringing.last { player.loop(next.sound); RingingPanel.shared.show() } else { player.stop(); RingingPanel.shared.hide() }
    }

    func repeatTimer(_ r: Ringing) {
        guard let t = timers.first(where: { $0.id == r.id }) else { return dismiss(r) }
        dismiss(r)
        startTimer(duration: t.duration, label: t.label, sound: t.sound)
    }

    func preview(_ sound: String) { if ringing.isEmpty { player.once(sound) } }

    // MARK: World clock

    func addCity(_ place: Place) {
        guard !cities.contains(where: { $0.zone == place.zone && $0.name == place.name }) else { return }
        cities.append(City(place))
    }

    func removeCity(_ city: City) { cities.removeAll { $0.id == city.id } }

    // MARK: Alarms

    func upsert(_ alarm: Alarm) {
        var alarm = alarm
        alarm.snoozedUntil = nil
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) { alarms[i] = alarm } else { alarms.append(alarm) }
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    func setEnabled(_ alarm: Alarm, _ on: Bool) {
        guard let i = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[i].enabled = on
        alarms[i].snoozedUntil = nil
    }

    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        if let r = ringing.first(where: { $0.id == alarm.id }) { dismiss(r) }
    }

    /// The soonest ring across all alarms.
    func nextAlarm(after now: Date) -> (Alarm, Date)? {
        alarms.compactMap { a in a.nextRing(after: now).map { (a, $0) } }.min { $0.1 < $1.1 }
    }

    // MARK: Timers

    func startTimer(duration: TimeInterval, label: String, sound: String) {
        guard duration >= 1 else { return }
        timers.insert(Countdown(duration: duration, label: label, sound: sound), at: 0)
        let recent = RecentTimer(duration: duration, label: label, sound: sound)
        recents.removeAll { $0 == recent }
        recents.insert(recent, at: 0)
        if recents.count > 8 { recents.removeLast(recents.count - 8) }
    }

    func toggle(_ timer: Countdown) {
        guard let i = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        let now = Date.now
        switch timers[i].state {
        case .running:
            timers[i].remaining = timers[i].left(at: now)
            timers[i].state = .paused
            timers[i].endsAt = nil
        case .paused:
            timers[i].endsAt = now.addingTimeInterval(timers[i].remaining)
            timers[i].state = .running
        case .done: break
        }
    }

    func extend(_ timer: Countdown, by seconds: TimeInterval) {
        guard let i = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        let now = Date.now
        if timers[i].state == .done, let r = ringing.first(where: { $0.id == timer.id }) {
            ringing.removeAll { $0.id == r.id }
            if let next = ringing.last { player.loop(next.sound); RingingPanel.shared.show() } else { player.stop(); RingingPanel.shared.hide() }
            timers[i].state = .running
            timers[i].endsAt = now
        }
        timers[i].duration = max(timers[i].duration, timers[i].left(at: now) + seconds)
        switch timers[i].state {
        case .running: timers[i].endsAt = (timers[i].endsAt ?? now).addingTimeInterval(seconds)
        case .paused: timers[i].remaining += seconds
        case .done: break
        }
    }

    func cancel(_ timer: Countdown) {
        if let r = ringing.first(where: { $0.id == timer.id }) { dismiss(r) } else { timers.removeAll { $0.id == timer.id } }
    }

    func removeRecent(_ r: RecentTimer) { recents.removeAll { $0 == r } }

    // MARK: Stopwatch

    func startStop() {
        let now = Date.now
        if let s = stopwatch.startedAt {
            stopwatch.banked += now.timeIntervalSince(s)
            stopwatch.startedAt = nil
        } else {
            stopwatch.startedAt = now
        }
    }

    func lapOrReset() {
        if stopwatch.running { stopwatch.marks.append(stopwatch.elapsed(at: .now)) } else { stopwatch = Stopwatch() }
    }
}

/// Loops a system sound until stopped (alarms), or plays it once (previews).
@MainActor
final class SoundPlayer {
    private var sound: NSSound?

    private func make(_ name: String) -> NSSound? {
        NSSound(contentsOfFile: "/System/Library/Sounds/\(name).aiff", byReference: true) ?? NSSound(named: name)
    }

    func loop(_ name: String) {
        stop()
        sound = make(name)
        sound?.loops = true
        sound?.play()
    }

    func once(_ name: String) {
        stop()
        sound = make(name)
        sound?.play()
    }

    func stop() {
        sound?.stop()
        sound = nil
    }
}

/// User preferences shared by the store and views.
enum Prefs {
    static var snoozeMinutes: Double {
        let v = UserDefaults.standard.double(forKey: "snoozeMinutes")
        return v > 0 ? v : 9
    }

    static func registerDefaults() {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "H"
        UserDefaults.standard.register(defaults: [
            "use24h": !template.contains("a"),
            "appearance": "system",
            "showSeconds": false,
            "menuBar": true,
            "snoozeMinutes": 9.0,
            "worldLayout": "list",
            "stopwatchAnalog": false,
        ])
    }

    static func applyAppearance(_ raw: String) {
        NSApp.appearance = raw == "light" ? NSAppearance(named: .aqua) : raw == "dark" ? NSAppearance(named: .darkAqua) : nil
    }
}
