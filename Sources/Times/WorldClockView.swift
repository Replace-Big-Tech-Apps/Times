import SwiftUI

struct WorldClockView: View {
    @Environment(TimesStore.self) private var store
    @AppStorage("worldLayout") private var layout = "list"
    @AppStorage("use24h") private var use24h = false
    @AppStorage("showSeconds") private var showSeconds = false
    @State private var picking = false

    var body: some View {
        VStack(spacing: 18) {
            mapCard.frame(height: 270)
            citiesCard
        }
        .sheet(isPresented: $picking) { CityPicker().environment(store) }
        .onChange(of: store.newItemTick) { if store.tab == .world { picking = true } }
    }

    private var mapCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            WidgetCard(eyebrow: "Daylight", title: Fmt.date(ctx.date, zone: .current, "EEEEdMMMM"),
                       status: TimeZone.current.abbreviation() ?? "") {
                DotMap(date: ctx.date, cities: store.cities)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    private var citiesCard: some View {
        WidgetCard(eyebrow: "World clock", title: "Cities", status: "\(store.cities.count) \(store.cities.count == 1 ? "city" : "cities")") {
            HStack(spacing: 5) {
                Chip(title: "LIST", on: layout == "list") { layout = "list" }
                Chip(title: "DIALS", on: layout == "grid") { layout = "grid" }
                SquareButton(symbol: "plus", help: "Add city (⌘N)", size: 26) { picking = true }
            }
        } content: {
            // Rows tick on their own, so the List itself is never rebuilt once a second.
            if store.cities.isEmpty {
                EmptyNote(text: "No cities yet. Add one to compare time zones.")
            } else if layout == "grid" {
                grid
            } else {
                list
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.cities) { city in
                CityRow(city: city, use24h: use24h, seconds: showSeconds) { store.removeCity(city) }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { store.cities.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { store.cities.remove(atOffsets: $0) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 0)], spacing: 0) {
                ForEach(store.cities) { city in
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let now = ctx.date
                    let clock = Fmt.clock(now, zone: city.timeZone, use24h: use24h)
                    VStack(spacing: 8) {
                        AnalogDial(date: now, zone: city.timeZone, size: 118, seconds: true)
                        Text(city.name).font(V3Font.condensed(19)).foregroundStyle(V3.ink).lineLimit(1)
                        Text("\(clock.time) \(clock.suffix) · \(Fmt.offset(city.timeZone, at: now))").eyebrow(V3.mute, size: 7)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .hairline([.bottom, .trailing])
                    }
                    .contextMenu { Button("Remove \(city.name)", role: .destructive) { store.removeCity(city) } }
                }
            }
        }
    }
}

struct CityRow: View {
    let city: City
    let use24h: Bool
    let seconds: Bool
    let remove: () -> Void
    @State private var hover = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in row(ctx.date) }
    }

    private func row(_ now: Date) -> some View {
        let clock = Fmt.clock(now, zone: city.timeZone, use24h: use24h, seconds: seconds)
        return HStack(spacing: 14) {
            AnalogDial(date: now, zone: city.timeZone, size: 38, seconds: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.offset(city.timeZone, at: now)).eyebrow(V3.mute, size: 7.5)
                HStack(spacing: 8) {
                    Text(city.name).font(V3Font.condensed(24)).foregroundStyle(V3.ink).lineLimit(1)
                    if city.zone == TimeZone.current.identifier {
                        Text("Here").eyebrow(.black, size: 6.5)
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background(V3.signal)
                    }
                }
            }
            Spacer()
            if hover {
                SquareButton(symbol: "xmark", help: "Remove \(city.name)", size: 28, action: remove)
                    .transition(.opacity)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(clock.time).font(V3Font.condensed(46, .ultraLight)).monospacedDigit().foregroundStyle(V3.ink)
                if !clock.suffix.isEmpty { Text(clock.suffix).eyebrow(V3.mute, size: 9) }
            }
        }
        .padding(.leading, 17)
        .padding(.trailing, 20)
        .frame(height: 80)
        .background(hover ? V3.paperSoft : V3.paper)
        .hairline(.bottom)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .contextMenu { Button("Remove \(city.name)", role: .destructive, action: remove) }
    }
}

/// Day faces are paper with ink hands; night faces are the V3ERA black disc with white hands.
struct AnalogDial: View {
    let date: Date
    var zone: TimeZone = .current
    let size: CGFloat
    var seconds = true

    var body: some View {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let h = Double(c.hour ?? 0), m = Double(c.minute ?? 0), s = Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1e9
        let night = h < 6 || h >= 18
        let face = night ? V3.night : Color.white
        let hand = night ? Color.white : V3.night

        return Canvas { ctx, sz in
            let r = sz.width / 2, center = CGPoint(x: r, y: r)
            ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: sz)), with: .color(face))
            // Day faces need an edge on paper, night faces on the dark desk.
            ctx.stroke(Path(ellipseIn: CGRect(origin: .zero, size: sz).insetBy(dx: 0.5, dy: 0.5)), with: .color(night ? .white.opacity(0.22) : .black.opacity(0.18)), lineWidth: 1)
            let ticks = size > 60 ? 60 : 12
            for i in 0..<ticks {
                let major = i % (ticks / 12) == 0
                let a = Double(i) / Double(ticks) * 2 * .pi
                let outer = r * 0.9, inner = r * (major ? 0.76 : 0.84)
                var p = Path()
                p.move(to: point(center, a, inner))
                p.addLine(to: point(center, a, outer))
                ctx.stroke(p, with: .color(hand.opacity(major ? 0.85 : 0.3)), lineWidth: major ? max(1, size / 80) : 0.6)
            }
            func stroke(_ angle: Double, _ length: Double, _ width: CGFloat, _ color: Color, tail: Double = 0.12) {
                var p = Path()
                p.move(to: point(center, angle + .pi, r * tail))
                p.addLine(to: point(center, angle, r * length))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            stroke((h.truncatingRemainder(dividingBy: 12) + m / 60) / 12 * 2 * .pi, 0.5, max(1.6, size / 26), hand)
            stroke((m + s / 60) / 60 * 2 * .pi, 0.74, max(1.2, size / 38), hand)
            if seconds { stroke(s / 60 * 2 * .pi, 0.8, max(0.8, size / 110), V3.signal, tail: 0.2) }
            let dot = max(2.5, size / 22)
            ctx.fill(Path(ellipseIn: CGRect(x: r - dot, y: r - dot, width: dot * 2, height: dot * 2)), with: .color(V3.signal))
        }
        .frame(width: size, height: size)
    }

    private func point(_ c: CGPoint, _ angle: Double, _ radius: Double) -> CGPoint {
        CGPoint(x: c.x + sin(angle) * radius, y: c.y - cos(angle) * radius)
    }
}

/// Dot-matrix world with the live day/night terminator, the sun, and a marker per city.
struct DotMap: View {
    let date: Date
    let cities: [City]
    private static let rows = 1..<48 // skip polar rows the mask leaves empty

    var body: some View {
        Canvas { ctx, size in
            let sun = Solar.subsolar(date)
            let total = CGFloat(WorldMask.cols), shown = CGFloat(Self.rows.count)
            let step = min(size.width / total, size.height / shown)
            let ox = (size.width - step * total) / 2, oy = (size.height - step * shown) / 2
            let rows = WorldMask.land.map { Array($0) }

            func lat(_ row: Double) -> Double { 90 - (row + 0.5) * 180 / Double(WorldMask.rows) }
            func lon(_ col: Double) -> Double { -180 + (col + 0.5) * 360 / Double(WorldMask.cols) }
            func place(_ la: Double, _ lo: Double) -> CGPoint {
                CGPoint(x: ox + CGFloat((lo + 180) / 360) * step * total,
                        y: oy + (CGFloat((90 - la) / 180 * Double(WorldMask.rows)) - CGFloat(Self.rows.lowerBound)) * step)
            }

            for (i, r) in Self.rows.enumerated() {
                for c in 0..<WorldMask.cols {
                    let land = rows[r][c] == "#"
                    let alt = Solar.altitude(lat: lat(Double(r)), lon: lon(Double(c)), sun: sun)
                    let day = min(1, max(0, (alt + 6) / 8)) // soft twilight band
                    let opacity = land ? 0.2 + 0.68 * day : 0.07 * (1 - day)
                    guard opacity > 0.01 else { continue }
                    let s = step * (land ? 0.62 : 0.34)
                    let rect = CGRect(x: ox + CGFloat(c) * step + (step - s) / 2, y: oy + CGFloat(i) * step + (step - s) / 2, width: s, height: s)
                    ctx.fill(Path(rect), with: .color(V3.ink.opacity(opacity)))
                }
            }

            let sp = place(sun.lat, sun.lon), sr = step * 1.5
            ctx.fill(Path(ellipseIn: CGRect(x: sp.x - sr * 2, y: sp.y - sr * 2, width: sr * 4, height: sr * 4)), with: .color(V3.signal.opacity(0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: sp.x - sr, y: sp.y - sr, width: sr * 2, height: sr * 2)), with: .color(V3.signal))

            // Markers first, then tags: each tag tries right, left, above, below and is dropped if all collide.
            let placed = cities.compactMap { c in c.lat.flatMap { la in c.lon.map { (c, place(la, $0)) } } }
            let m = step * 1.1
            var taken = placed.map { CGRect(x: $0.1.x - m, y: $0.1.y - m, width: m * 2, height: m * 2) }
            for (_, p) in placed {
                ctx.fill(Path(CGRect(x: p.x - m, y: p.y - m, width: m * 2, height: m * 2)), with: .color(V3.ink))
                ctx.fill(Path(CGRect(x: p.x - m * 0.5, y: p.y - m * 0.5, width: m, height: m)), with: .color(V3.signal))
            }
            for (city, p) in placed {
                let label = ctx.resolve(Text(city.name.uppercased()).font(V3Font.mono(7, .bold)).tracking(1).foregroundStyle(V3.inverse))
                let ls = label.measure(in: size)
                let w = ls.width + 8, h = ls.height + 4
                let options = [CGRect(x: p.x + m + 3, y: p.y - h / 2, width: w, height: h),
                               CGRect(x: p.x - m - 3 - w, y: p.y - h / 2, width: w, height: h),
                               CGRect(x: p.x - w / 2, y: p.y - m - 3 - h, width: w, height: h),
                               CGRect(x: p.x - w / 2, y: p.y + m + 3, width: w, height: h)]
                guard let tag = options.first(where: { o in !taken.contains { $0.intersects(o.insetBy(dx: -1, dy: -1)) } }) else { continue }
                taken.append(tag)
                ctx.fill(Path(tag), with: .color(V3.ink))
                ctx.draw(label, at: CGPoint(x: tag.minX + 4, y: tag.midY), anchor: .leading)
            }
        }
    }
}

enum Solar {
    struct Point { let lat: Double; let lon: Double; let decl: Double }

    /// Where the sun is directly overhead (low-precision almanac, good to ~0.1°).
    static func subsolar(_ date: Date) -> Point {
        let rad = Double.pi / 180
        let n = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545.0
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g = (357.528 + 0.9856003 * n) * rad
        let lambda = (L + 1.915 * sin(g) + 0.020 * sin(2 * g)) * rad
        let eps = (23.439 - 0.0000004 * n) * rad
        let decl = asin(sin(eps) * sin(lambda)) / rad
        let ra = atan2(cos(eps) * sin(lambda), cos(lambda)) / rad
        let gmst = (280.46061837 + 360.98564736629 * n).truncatingRemainder(dividingBy: 360)
        var lon = (ra - gmst).truncatingRemainder(dividingBy: 360)
        if lon > 180 { lon -= 360 } else if lon < -180 { lon += 360 }
        return Point(lat: decl, lon: lon, decl: decl)
    }

    /// Sun altitude in degrees at a place.
    static func altitude(lat: Double, lon: Double, sun: Point) -> Double {
        let rad = Double.pi / 180
        let v = sin(lat * rad) * sin(sun.decl * rad) + cos(lat * rad) * cos(sun.decl * rad) * cos((lon - sun.lon) * rad)
        return asin(max(-1, min(1, v))) / rad
    }
}

struct CityPicker: View {
    @Environment(TimesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @AppStorage("use24h") private var use24h = false

    var body: some View {
        let results = Places.search(query)
        WidgetCard(eyebrow: "Add city", title: "Choose a city", status: "\(results.count) found") {
            SquareButton(symbol: "xmark", help: "Cancel", size: 26) { dismiss() }
        } content: {
            VStack(spacing: 0) {
                FieldBox(placeholder: "Search cities, countries or zones", text: $query) {
                    if let first = results.first { add(first) }
                }
                .hairline(.bottom)
                let now = Date.now
                List(results.prefix(300)) { place in
                    Button { add(place) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name).font(V3Font.condensed(17)).foregroundStyle(V3.ink)
                                Text(place.region).eyebrow(V3.mute, size: 7)
                            }
                            Spacer()
                            let tz = TimeZone(identifier: place.zone) ?? .current
                            let c = Fmt.clock(now, zone: tz, use24h: use24h)
                            Text("\(c.time) \(c.suffix)").font(V3Font.mono(10, .medium)).foregroundStyle(V3.mute)
                        }
                        .padding(.horizontal, 17)
                        .frame(height: 46)
                        .contentShape(Rectangle())
                        .hairline(.bottom)
                    }
                    .buttonStyle(RowButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: 440, height: 520)
        .padding(1)
        .background(V3.desk)
        .onExitCommand { dismiss() }
    }

    private func add(_ place: Place) {
        store.addCity(place)
        dismiss()
    }
}

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration) }

    private struct Row: View {
        let configuration: Configuration
        @State private var hover = false
        var body: some View {
            configuration.label
                .background(configuration.isPressed ? V3.signal : hover ? V3.paperSoft : V3.paper)
                .onHover { hover = $0 }
        }
    }
}

struct EmptyNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(V3Font.condensed(17))
            .foregroundStyle(V3.whisper)
            .multilineTextAlignment(.center)
            .padding(48)
            .frame(maxWidth: .infinity)
    }
}
