import AppKit
import SwiftUI

@main
struct TimesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = TimesStore.shared
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("menuBar") private var menuBar = true

    init() {
        Prefs.registerDefaults()
    }

    var body: some Scene {
        Window("Times", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 860, minHeight: 600)
                .onAppear { Prefs.applyAppearance(appearance) }
                .onChange(of: appearance) { _, new in Prefs.applyAppearance(new) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1040, height: 720)
        .commands { TimesCommands(store: store) }

        MenuBarExtra(isInserted: $menuBar) {
            MenuBarPanel().environment(store)
        } label: {
            MenuBarLabel().environment(store)
        }
        .menuBarExtraStyle(.window)

        SwiftUI.Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        Prefs.applyAppearance(UserDefaults.standard.string(forKey: "appearance") ?? "system")
        Notifier.setUp()
        TimesStore.shared.start()
    }

    /// Alarms need the app alive, so closing the window keeps it running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        TimesStore.shared.save()
    }
}

struct TimesCommands: Commands {
    let store: TimesStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(newTitle) {
                openWindow(id: "main")
                store.newItemTick += 1
            }
            .keyboardShortcut("n")
        }
        CommandMenu("Clock") {
            ForEach(Tab.allCases) { tab in
                Button(tab.title) {
                    openWindow(id: "main")
                    store.tab = tab
                }
                .keyboardShortcut(KeyEquivalent(Character("\(tab.rawValue + 1)")))
            }
            Divider()
            Button(store.stopwatch.running ? "Stop Stopwatch" : "Start Stopwatch") { store.startStop() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button(store.stopwatch.running ? "Lap" : "Reset Stopwatch") { store.lapOrReset() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(store.stopwatch.isReset)
        }
    }

    private var newTitle: String {
        switch store.tab {
        case .world: "Add City…"
        case .alarms: "New Alarm…"
        case .stopwatch: "Lap"
        case .timers: "New Timer"
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("use24h") private var use24h = false
    @AppStorage("showSeconds") private var showSeconds = false
    @AppStorage("menuBar") private var menuBar = true
    @AppStorage("snoozeMinutes") private var snooze = 9.0

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Toggle("24-hour time", isOn: $use24h)
            Toggle("Show seconds in World Clock", isOn: $showSeconds)
            Toggle("Show in menu bar", isOn: $menuBar)
            Picker("Snooze length", selection: $snooze) {
                ForEach([5.0, 9, 10, 15, 20], id: \.self) { Text("\(Int($0)) minutes").tag($0) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }
}
