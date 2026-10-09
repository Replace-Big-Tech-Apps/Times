import Foundation

enum Tab: Int, CaseIterable, Identifiable, Codable {
    case world, alarms, stopwatch, timers
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .world: "World Clock"
        case .alarms: "Alarms"
        case .stopwatch: "Stopwatch"
        case .timers: "Timers"
        }
    }
}

struct City: Codable, Identifiable, Hashable {
    var id = UUID()
    var zone: String
    var name: String
    var lat: Double?
    var lon: Double?

    var timeZone: TimeZone { TimeZone(identifier: zone) ?? .current }

    init(_ place: Place) {
        zone = place.zone; name = place.name; lat = place.lat; lon = place.lon
    }
}

struct Alarm: Codable, Identifiable, Hashable {
    var id = UUID()
    var hour = 7
    var minute = 0
    var label = ""
    /// Calendar weekdays, 1 = Sunday. Empty = rings once.
    var days: Set<Int> = []
    var enabled = true
    var sound = Sounds.alarmDefault
    var snooze = true
    var snoozedUntil: Date?

    var title: String { label.isEmpty ? "Alarm" : label }

    /// Next scheduled ring strictly after `date`, ignoring snooze.
    func nextFire(after date: Date) -> Date? {
        let cal = Calendar.current
        let base = DateComponents(hour: hour, minute: minute, second: 0)
        if days.isEmpty { return cal.nextDate(after: date, matching: base, matchingPolicy: .nextTime) }
        return days.compactMap { day -> Date? in
            var c = base
            c.weekday = day
            return cal.nextDate(after: date, matching: c, matchingPolicy: .nextTime)
        }.min()
    }

    /// When this alarm will actually ring next (snooze wins), or nil if off.
    func nextRing(after date: Date) -> Date? {
        guard enabled else { return nil }
        if let snoozedUntil, snoozedUntil > date { return snoozedUntil }
        return nextFire(after: date)
    }

    var repeatText: String {
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        switch days {
        case []: return "Never"
        case Set(1...7): return "Every day"
        case weekdays: return "Weekdays"
        case [1, 7]: return "Weekends"
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            return Alarm.weekOrder.filter(days.contains).map { symbols[$0 - 1] }.joined(separator: " ")
        }
    }

    /// Locale-aware week order (Monday first in most of Europe).
    static var weekOrder: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
}

enum TimerState: String, Codable { case running, paused, done }

struct Countdown: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String
    var duration: TimeInterval
    var sound: String
    var state: TimerState = .running
    var endsAt: Date?
    var remaining: TimeInterval

    init(duration: TimeInterval, label: String, sound: String, now: Date = .now) {
        self.duration = duration; self.label = label; self.sound = sound
        remaining = duration
        endsAt = now.addingTimeInterval(duration)
    }

    var title: String { label.isEmpty ? Fmt.durationName(duration) : label }

    func left(at now: Date) -> TimeInterval {
        switch state {
        case .running: max(0, (endsAt ?? now).timeIntervalSince(now))
        case .paused: remaining
        case .done: 0
        }
    }

    func progress(at now: Date) -> Double {
        duration > 0 ? min(1, max(0, left(at: now) / duration)) : 0
    }
}

struct RecentTimer: Codable, Hashable, Identifiable {
    var duration: TimeInterval
    var label: String
    var sound: String
    var id: String { "\(duration)|\(label)|\(sound)" }
}

struct Stopwatch: Codable, Hashable {
    var startedAt: Date?
    var banked: TimeInterval = 0
    /// Cumulative elapsed time at each lap press.
    var marks: [TimeInterval] = []

    var running: Bool { startedAt != nil }
    var isReset: Bool { !running && banked == 0 && marks.isEmpty }

    func elapsed(at now: Date) -> TimeInterval {
        banked + (startedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// Completed lap durations, oldest first.
    var laps: [TimeInterval] {
        zip(marks, [0] + marks).map { $0 - $1 }
    }
}

struct Ringing: Identifiable, Equatable {
    enum Kind { case alarm, timer }
    let id: UUID
    let kind: Kind
    let title: String
    let sound: String
    let canSnooze: Bool
    let at: Date
}

/// Everything that survives a relaunch.
struct Snapshot: Codable {
    var cities: [City] = []
    var alarms: [Alarm] = []
    var timers: [Countdown] = []
    var recents: [RecentTimer] = []
    var stopwatch = Stopwatch()
    var lastRun: Date?
    var tab: Tab = .world
}

enum Sounds {
    static let all = ["Glass", "Hero", "Submarine", "Ping", "Funk", "Blow", "Bottle", "Frog", "Morse", "Pop", "Purr", "Sosumi", "Tink", "Basso"]
    static let alarmDefault = "Submarine"
    static let timerDefault = "Glass"
}
