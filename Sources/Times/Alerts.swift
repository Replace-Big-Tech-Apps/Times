import AppKit
import SwiftUI
import UserNotifications

/// Backup delivery for when Times isn't running: every enabled alarm and running timer is mirrored
/// as a pending local notification. While the app runs, the in-app panel rings instead.
enum Notifier {
    @MainActor private static var ready = false
    private static let delegate = Delegate()

    /// UNUserNotificationCenter traps outside a real .app bundle (e.g. `swift run`).
    private static var available: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    @MainActor static func setUp() {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        ready = true
    }

    @MainActor static func sync(_ store: TimesStore) {
        guard ready else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = Date.now
        var requests: [UNNotificationRequest] = []

        for alarm in store.alarms where alarm.enabled {
            let content = UNMutableNotificationContent()
            content.title = alarm.title
            content.body = Fmt.clock(hour: alarm.hour, minute: alarm.minute, use24h: UserDefaults.standard.bool(forKey: "use24h")).time
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            if let s = alarm.snoozedUntil, s > now {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: s.timeIntervalSince(now), repeats: false)
                requests.append(UNNotificationRequest(identifier: "alarm.\(alarm.id).snooze", content: content, trigger: trigger))
            }
            let days: [Int?] = alarm.days.isEmpty ? [nil] : alarm.days.sorted()
            for day in days {
                let parts = DateComponents(hour: alarm.hour, minute: alarm.minute, weekday: day)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: day != nil)
                requests.append(UNNotificationRequest(identifier: "alarm.\(alarm.id).\(day ?? 0)", content: content, trigger: trigger))
            }
        }
        for timer in store.timers where timer.state == .running {
            let left = timer.left(at: now)
            guard left >= 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Timer"
            content.body = timer.title
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: left, repeats: false)
            requests.append(UNNotificationRequest(identifier: "timer.\(timer.id)", content: content, trigger: trigger))
        }
        requests.forEach { center.add($0) }
    }

    final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([]) // the floating panel is already ringing
        }
    }
}

/// The ringing alert: a floating V3ERA widget over every Space, like a desk widget.
@MainActor
final class RingingPanel {
    static let shared = RingingPanel()
    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isFloatingPanel = true
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = false
            p.isMovableByWindowBackground = true
            let host = NSHostingView(rootView: RingingView().environment(TimesStore.shared))
            host.sizingOptions = [.preferredContentSize]
            p.contentView = host
            panel = p
        }
        guard let panel else { return }
        if let screen = NSScreen.main {
            let size = panel.contentView?.fittingSize ?? panel.frame.size
            panel.setFrame(NSRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 24,
                                  width: size.width, height: size.height), display: true)
        }
        panel.orderFrontRegardless()
        NSApp.requestUserAttention(.criticalRequest)
    }

    func hide() { panel?.orderOut(nil) }
}

struct RingingView: View {
    @Environment(TimesStore.self) private var store
    @AppStorage("use24h") private var use24h = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(store.ringing.reversed()) { r in card(r) }
        }
        .padding(24) // room for the shadow
        .fixedSize()
    }

    private func card(_ r: Ringing) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(r.kind == .alarm ? "Alarm" : "Timer done").eyebrow(.white.opacity(0.45), size: 7.5)
                    Text(r.title).font(V3Font.condensed(20)).foregroundStyle(.white).lineLimit(1)
                }
                Spacer()
                PulseDot()
            }
            .padding(.horizontal, 17)
            .frame(height: 60)
            .hairline(.bottom, color: .white.opacity(0.12))

            let clock = Fmt.clock(r.at, use24h: use24h)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(r.kind == .timer ? "00:00" : clock.time)
                    .font(V3Font.condensed(84, .ultraLight)).monospacedDigit()
                    .foregroundStyle(r.kind == .timer ? V3.signal : .white)
                if r.kind == .alarm, !clock.suffix.isEmpty {
                    Text(clock.suffix).font(V3Font.mono(11, .semibold)).foregroundStyle(V3.signal)
                }
            }
            .padding(.vertical, 22)

            HStack(spacing: 1) {
                if r.canSnooze {
                    BarButton(title: "Snooze \(Int(Prefs.snoozeMinutes)) min", kind: .signal, height: 44) { store.dismiss(r, snooze: true) }
                }
                if r.kind == .timer {
                    BarButton(title: "Repeat", kind: .signal, height: 44) { store.repeatTimer(r) }
                }
                BarButton(title: "Stop", kind: .danger, height: 44) { store.dismiss(r) }
            }
            .background(Color.white.opacity(0.12))
        }
        .frame(width: 330)
        .background(V3.night)
        .clipShape(RoundedRectangle(cornerRadius: V3.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: V3.radiusCard).strokeBorder(V3.done.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
        .environment(\.colorScheme, .dark)
    }
}

/// Blinking red square, V3ERA's "RINGING" status.
struct PulseDot: View {
    @State private var on = false
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(V3.done)
            .frame(width: 9, height: 9)
            .opacity(on ? 1 : 0.25)
            .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { on = true } }
    }
}
