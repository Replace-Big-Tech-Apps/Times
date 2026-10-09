import Foundation

/// A pickable city: every IANA zone, plus well-known cities that share a zone with another.
struct Place: Hashable, Identifiable {
    let zone: String
    let name: String
    let region: String
    let lat: Double?
    let lon: Double?
    var id: String { "\(zone)|\(name)" }
}

enum Places {
    static let all: [Place] = {
        let coords = zoneTab()
        var places = TimeZone.knownTimeZoneIdentifiers.compactMap { zone -> Place? in
            let parts = zone.split(separator: "/")
            guard parts.count >= 2, !["Etc", "SystemV", "US", "Canada", "Brazil", "Mexico", "Chile"].contains(String(parts[0])) else { return nil }
            let name = parts.last!.replacingOccurrences(of: "_", with: " ")
            let entry = coords[zone]
            let country = entry.flatMap { Locale.current.localizedString(forRegionCode: $0.country) }
            return Place(zone: zone, name: name, region: country ?? String(parts[parts.count - 2]).replacingOccurrences(of: "_", with: " "),
                         lat: entry?.lat, lon: entry?.lon)
        }
        places += aliases.map { Place(zone: $0.zone, name: $0.name, region: $0.region, lat: $0.lat, lon: $0.lon) }
        return places.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    /// The city for the Mac's own time zone.
    static var local: Place {
        let zone = TimeZone.current.identifier
        return all.first { $0.zone == zone } ?? Place(zone: zone, name: zone.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? "Local", region: "", lat: nil, lon: nil)
    }

    static func named(_ name: String) -> Place? { all.first { $0.name == name } }

    static func search(_ query: String) -> [Place] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.region.localizedCaseInsensitiveContains(q)
                || (TimeZone(identifier: $0.zone)?.abbreviation()?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    // MARK: zone.tab ("DE  +5230+01322  Europe/Berlin")

    private static func zoneTab() -> [String: (country: String, lat: Double, lon: Double)] {
        guard let text = try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8) else { return [:] }
        var out: [String: (String, Double, Double)] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let cols = line.split(separator: "\t")
            guard cols.count >= 3, let (lat, lon) = parseISO6709(String(cols[1])) else { continue }
            out[String(cols[2])] = (String(cols[0]), lat, lon)
        }
        return out
    }

    private static func parseISO6709(_ s: String) -> (Double, Double)? {
        guard let split = s.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        func value(_ part: Substring, degreeDigits: Int) -> Double? {
            let sign: Double = part.first == "-" ? -1 : 1
            let digits = Array(part.dropFirst())
            guard digits.count >= degreeDigits + 2,
                  let d = Double(String(digits[0..<degreeDigits])),
                  let m = Double(String(digits[degreeDigits..<degreeDigits + 2])) else { return nil }
            let sec = digits.count >= degreeDigits + 4 ? Double(String(digits[(degreeDigits + 2)..<(degreeDigits + 4)])) ?? 0 : 0
            return sign * (d + m / 60 + sec / 3600)
        }
        guard let lat = value(s[s.startIndex..<split], degreeDigits: 2), let lon = value(s[split...], degreeDigits: 3) else { return nil }
        return (lat, lon)
    }

    private static let aliases: [(name: String, region: String, zone: String, lat: Double, lon: Double)] = [
        ("Cupertino", "United States", "America/Los_Angeles", 37.32, -122.03),
        ("San Francisco", "United States", "America/Los_Angeles", 37.77, -122.42),
        ("Seattle", "United States", "America/Los_Angeles", 47.61, -122.33),
        ("Las Vegas", "United States", "America/Los_Angeles", 36.17, -115.14),
        ("San Diego", "United States", "America/Los_Angeles", 32.72, -117.16),
        ("Dallas", "United States", "America/Chicago", 32.78, -96.80),
        ("Houston", "United States", "America/Chicago", 29.76, -95.37),
        ("Austin", "United States", "America/Chicago", 30.27, -97.74),
        ("Boston", "United States", "America/New_York", 42.36, -71.06),
        ("Washington, D.C.", "United States", "America/New_York", 38.91, -77.04),
        ("Miami", "United States", "America/New_York", 25.76, -80.19),
        ("Atlanta", "United States", "America/New_York", 33.75, -84.39),
        ("Montreal", "Canada", "America/Toronto", 45.50, -73.57),
        ("Munich", "Germany", "Europe/Berlin", 48.14, 11.58),
        ("Hamburg", "Germany", "Europe/Berlin", 53.55, 9.99),
        ("Frankfurt", "Germany", "Europe/Berlin", 50.11, 8.68),
        ("Barcelona", "Spain", "Europe/Madrid", 41.39, 2.17),
        ("Milan", "Italy", "Europe/Rome", 45.46, 9.19),
        ("Salzburg", "Austria", "Europe/Vienna", 47.81, 13.06),
        ("Graz", "Austria", "Europe/Vienna", 47.07, 15.44),
        ("Geneva", "Switzerland", "Europe/Zurich", 46.20, 6.14),
        ("Edinburgh", "United Kingdom", "Europe/London", 55.95, -3.19),
        ("Manchester", "United Kingdom", "Europe/London", 53.48, -2.24),
        ("Beijing", "China", "Asia/Shanghai", 39.90, 116.41),
        ("Shenzhen", "China", "Asia/Shanghai", 22.54, 114.06),
        ("Mumbai", "India", "Asia/Kolkata", 19.08, 72.88),
        ("New Delhi", "India", "Asia/Kolkata", 28.61, 77.21),
        ("Bangalore", "India", "Asia/Kolkata", 12.97, 77.59),
        ("Osaka", "Japan", "Asia/Tokyo", 34.69, 135.50),
        ("Kyoto", "Japan", "Asia/Tokyo", 35.01, 135.77),
        ("Abu Dhabi", "United Arab Emirates", "Asia/Dubai", 24.45, 54.38),
        ("Rio de Janeiro", "Brazil", "America/Sao_Paulo", -22.91, -43.17),
        ("Canberra", "Australia", "Australia/Sydney", -35.28, 149.13),
        ("Wellington", "New Zealand", "Pacific/Auckland", -41.29, 174.78),
        ("Cape Town", "South Africa", "Africa/Johannesburg", -33.92, 18.42),
    ]
}
