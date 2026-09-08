import Cocoa
import Carbon.HIToolbox
import ApplicationServices

// MARK: - Clicker engine

final class Clicker {
    private(set) var isRunning = false
    var interval: TimeInterval = 0.1
    var spreadMode = false

    private let queue = DispatchQueue(label: "local.autoclicker.clicker", qos: .userInteractive)
    private let gate = DispatchSemaphore(value: 0)

    var onStateChange: ((Bool) -> Void)?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        queue.async { [weak self] in
            guard let self else { return }
            self.runLoop()
            self.onStateChange?(false)
        }
        onStateChange?(true)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        gate.signal()
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    private func runLoop() {
        var target = DispatchTime.now().uptimeNanoseconds
        while isRunning {
            if spreadMode {
                let jitter = Double.random(in: 0.5...1.5)
                target = DispatchTime.now().uptimeNanoseconds + UInt64(interval * jitter * 1_000_000_000)
            } else {
                target += UInt64(interval * 1_000_000_000)
            }
            let waitNanos = Int64(target) - Int64(DispatchTime.now().uptimeNanoseconds)
            if waitNanos > 0 {
                _ = gate.wait(timeout: .now() + Double(waitNanos) / 1_000_000_000)
            }
            guard isRunning else { return }
            clickAtCursor()
        }
    }

    private func clickAtCursor() {
        guard let raw = CGEvent(source: nil)?.location else { return }
        let loc = CGPoint(x: raw.x.rounded(), y: raw.y.rounded())
        let src = CGEventSource(stateID: .hidSystemState)

        let move = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: loc, mouseButton: .left)
        move?.post(tap: .cghidEventTap)

        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: loc, mouseButton: .left)
        down?.post(tap: .cghidEventTap)

        let upDelay = min(0.03, interval * 0.4)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + upDelay) {
            let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: loc, mouseButton: .left)
            up?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let clicker = Clicker()
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?

    // Регистрируем горячую клавишу ⌥⌘K
    private let hotKeyID = FourCharCode(0x41434B4B) // 'ACKK'

    func applicationDidFinishLaunching(_ notification: Notification) {
        clicker.onStateChange = { [weak self] running in
            self?.updateMenu(running: running)
        }
        setupStatusItem()
        registerHotKey()
        updateMenu(running: false)
        if !AXIsProcessTrusted() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            let alert = NSAlert()
            alert.messageText = "AutoClicker needs access"
            alert.informativeText = "Enable the AutoClicker checkbox under Accessibility or clicks will not work."
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clicker.stop()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }

    // MARK: Status item menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = ""
        if let iconPath = Bundle.main.path(forResource: "statusbar", ofType: "png"),
           let icon = NSImage(contentsOfFile: iconPath) {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "🖱"
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateMenu(running: Bool) {
        let menu = statusItem.menu ?? NSMenu()
        menu.removeAllItems()

        let toggle = NSMenuItem(
            title: running ? "Stop (⌥⌘K)" : "Run (⌥⌘K)",
            action: #selector(toggleClicker),
            keyEquivalent: "k"
        )
        toggle.keyEquivalentModifierMask = [.option, .command]
        toggle.target = self
        toggle.state = running ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())

        // Выбор скорости
        menu.addItem(sectionTitle("Click speed:"))
        for (label, interval) in [("1 click/s", 1.0), ("5 clicks/s", 0.2), ("10 clicks/s", 0.1), ("20 clicks/s", 0.05), ("50 clicks/s", 0.02)] {
            let item = NSMenuItem(title: label, action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.state = abs(clicker.interval - interval) < 0.0001 ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Спред-режим: случайные паузы между кликами
        let spread = NSMenuItem(title: "Spread mode (random intervals)", action: #selector(toggleSpread), keyEquivalent: "")
        spread.target = self
        spread.state = clicker.spreadMode ? .on : .off
        menu.addItem(spread)

        menu.addItem(.separator())
        if !AXIsProcessTrusted() {
            let grant = NSMenuItem(title: "Grant Accessibility access…  ⚠️", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        }

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.appearsDisabled = running
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenu(running: clicker.isRunning)
    }

    private func sectionTitle(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: Actions

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func toggleClicker() {
        clicker.toggle()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        clicker.stop()
        clicker.interval = sender.representedObject as! TimeInterval
        updateMenu(running: false)
    }

    @objc private func toggleSpread() {
        clicker.stop()
        clicker.spreadMode.toggle()
        updateMenu(running: false)
    }

    // MARK: Global hotkey via Carbon

    private func registerHotKey() {
        let hotKeyIDRef = EventHotKeyID(signature: FourCharCode(0x484B4521) /* 'HKE!' */, id: hotKeyID)
        // keyCode = 40 (K), modifiers = cmd + option
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_K),
            UInt32(cmdKey | optionKey),
            hotKeyIDRef,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("Failed to register hotkey: \(status)")
        }

        // Установка обработчика событий горячей клавиши
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, refcon) -> OSStatus in
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                delegate.clicker.toggle()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
        _ = hotKeyIDRef
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // без иконки в Dock
app.run()
