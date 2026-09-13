//
//  XMenuBarCtlApp.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI

@main
struct XMenuBarCtlApp: App {
    @State private var engine = XMenuBarCtlEngine()

    var body: some Scene {
        Window("XMenuBarCtl", id: "xmenubarctl-main") {
            ContentView(engine: engine)
                .frame(minWidth: 600, minHeight: 500)
                .onOpenURL { url in
                    engine.handleIncoming(url: url)
                }
        }
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["*"])
    }
}

@Observable
final class XMenuBarCtlEngine {
    var log: [LogEntry] = []
    var callbacks: [CallbackResponse] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let direction: Direction
        let message: String

        enum Direction: String { case sent = "→ SENT", received = "← GOT" }
    }

    struct CallbackResponse: Identifiable {
        let id = UUID()
        let timestamp: Date
        let rawData: String
        var parsed: [String: Any]? {
            guard let d = rawData.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
            else { return nil }
            return json
        }
    }

    func handleIncoming(url: URL) {
        guard url.scheme?.lowercased() == "xmenubarctl" else { return }
        handleCallback(url: url)
    }

    private func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataItem = components.queryItems?.first(where: { $0.name == "data" })?.value
        else { return }

        let entry = CallbackResponse(timestamp: Date(), rawData: dataItem)
        callbacks.insert(entry, at: 0)
        log.insert(LogEntry(timestamp: Date(), direction: .received, message: dataItem), at: 0)
    }

    func send(url: String) {
        log.insert(LogEntry(timestamp: Date(), direction: .sent, message: url), at: 0)
        guard let url = URL(string: url) else { return }
        NSWorkspace.shared.open(url)
    }

    func sendSet(key: String, value: String, display: String = "") {
        var url = "xmenubar://set?key=\(key)&value=\(value)"
        if !display.isEmpty { url += "&display=\(display)" }
        send(url: url)
    }

    func sendToggle(key: String, display: String = "") {
        var url = "xmenubar://toggle?key=\(key)"
        if !display.isEmpty { url += "&display=\(display)" }
        send(url: url)
    }

    func sendGet(key: String, display: String = "") {
        let callback = "xmenubarctl://response"
        var url = "xmenubar://get?key=\(key)&callback=\(callback)"
        if !display.isEmpty { url += "&display=\(display)" }
        send(url: url)
    }

    func sendAuthorize() {
        send(url: "xmenubar://authorize")
    }

    func sendAction(_ action: String) {
        send(url: "xmenubar://\(action)")
    }
}
