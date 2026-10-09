import Foundation

enum Fmt {
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let key = "\(format)|\(zone.identifier)"
        if let f = cache[key] { return f }
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = zone
        f.dateFormat = format
        cache[key] = f
        return f
    }

    /// "9:41" + "AM", or "09:41" + "" in 24-hour mode.
    static func clock(_ date: Date, zone: TimeZone = .current, use24h: Bool, seconds: Bool = false) -> (time: String, suffix: String) {
        let pattern = (use24h ? "HH:mm" : "h:mm") + (seconds ? ":ss" : "")
        return (formatter(pattern, zone).string(from: date), use24h ? "" : formatter("a", zone).string(from: date))
    }

    static func clock(hour: Int, minute: Int, use24h: Bool) -> (time: String, suffix: String) {
        if use24h { return (String(format: "%02d:%02d", hour, minute), "") }
        let symbols = Calendar.current.amSymbol.isEmpty ? ("AM", "PM") : (Calendar.current.amSymbol, Calendar.current.pmSymbol)
        return (String(format: "%d:%02d", hour % 12 == 0 ? 12 : hour % 12, minute), hour < 12 ? symbols.0 : symbols.1)
    }

    static func date(_ date: Date, zone: TimeZone = .current, _ template: String = "EEEEdMMMMy") -> String {
        let f = formatter(DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current) ?? "EEEE, d MMMM", zone)
        return f.string(from: date)
    }

    /// "TODAY, +6 HRS" relative to the Mac's own zone.
    static func offset(_ zone: TimeZone, at now: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let here = cal.dateComponents([.year, .month, .day], from: now)
        cal.timeZone = zone
        let there = cal.dateComponents([.year, .month, .day], from: now)
        let a = (here.year ?? 0, here.month ?? 0, here.day ?? 0), b = (there.year ?? 0, there.month ?? 0, there.day ?? 0)
        let day = b > a ? "Tomorrow" : b < a ? "Yesterday" : "Today"
        let diff = zone.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
        if diff == 0 { return "\(day), same time" }
        let h = abs(diff) / 3600, m = abs(diff) % 3600 / 60
        let sign = diff > 0 ? "+" : "−"
        let amount = m == 0 ? "\(h)" : "\(h):\(String(format: "%02d", m))"
        return "\(day), \(sign)\(amount) \(h == 1 && m == 0 ? "HR" : "HRS")"
    }

    /// Stopwatch: "01:23.45" or "1:02:03.45".
    static func stopwatch(_ t: TimeInterval) -> String {
        let cs = Int((max(0, t) * 100).rounded(.down))
        let h = cs / 360_000, m = cs / 6000 % 60, s = cs / 100 % 60, c = cs % 100
        return h > 0 ? String(format: "%d:%02d:%02d.%02d", h, m, s, c) : String(format: "%02d:%02d.%02d", m, s, c)
    }

    /// Countdown: "04:59" or "1:04:59", rounding up so it never shows 00:00 while running.
    static func countdown(_ t: TimeInterval) -> String {
        let whole = Int(max(0, t).rounded(.up))
        let h = whole / 3600, m = whole / 60 % 60, s = whole % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "25 min", "1 hr 30 min", "45 sec".
    static func durationName(_ t: TimeInterval) -> String {
        let whole = Int(t.rounded())
        let h = whole / 3600, m = whole / 60 % 60, s = whole % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hr") }
        if m > 0 { parts.append("\(m) min") }
        if s > 0 { parts.append("\(s) sec") }
        return parts.isEmpty ? "0 sec" : parts.joined(separator: " ")
    }

    /// "in 6 hr 12 min" until an alarm.
    static func until(_ date: Date, from now: Date) -> String {
        let mins = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        if mins < 1 { return "in under a minute" }
        let d = mins / 1440, h = mins / 60 % 24, m = mins % 60
        var parts: [String] = []
        if d > 0 { parts.append("\(d) d") }
        if h > 0 { parts.append("\(h) hr") }
        if m > 0 && d == 0 { parts.append("\(m) min") }
        return "in " + parts.joined(separator: " ")
    }

    /// V3ERA's composer grammar: "7" = minutes, "7:30" = m:s, "1:05:00" = h:m:s, "1h 20m", "90s", "1.5h".
    static func parseDuration(_ text: String) -> TimeInterval {
        let value = text.trimmingCharacters(in: .whitespaces).lowercased()
        if value.isEmpty { return 0 }
        if let n = Double(value) { return n * 60 }
        let parts = value.split(separator: ":").map { Double($0) }
        if parts.count >= 2, parts.count <= 3, parts.allSatisfy({ $0 != nil }) {
            let p = parts.map { $0! }
            return p.count == 3 ? p[0] * 3600 + p[1] * 60 + p[2] : p[0] * 60 + p[1]
        }
        var total = 0.0, found = false
        let regex = #/(\d+(?:\.\d+)?)\s*(h|hr|hrs|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)\b/#
        for match in value.matches(of: regex) {
            guard let n = Double(match.1) else { continue }
            let unit = match.2.first!
            total += n * (unit == "h" ? 3600 : unit == "s" ? 1 : 60)
            found = true
        }
        return found ? total : 0
    }
}
