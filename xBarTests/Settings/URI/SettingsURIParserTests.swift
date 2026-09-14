//
//  SettingsURIParserTests.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import Testing
@testable import xBar

/// Parses `string` as a `xmenubar://` URL, failing the test if it is not a valid URL.
private func parse(_ string: String) throws -> SettingsURIRequest {
    let url = try #require(URL(string: string), "Could not build a URL from \(string)")
    return SettingsURIParser.parse(url)
}

@Suite("SettingsURIParser")
struct SettingsURIParserTests {
    @Suite("set")
    struct SetRoute {
        @Test("Key and value produce a set route")
        func keyAndValue() throws {
            #expect(try parse("xmenubar://set?key=autoRehide&value=true").route
                == .set(key: "autoRehide", value: "true", displayUUID: nil))
        }

        @Test("Display parameter is carried through")
        func displayUUID() throws {
            #expect(try parse("xmenubar://set?key=useIceBar&value=false&display=ABC-123").route
                == .set(key: "useIceBar", value: "false", displayUUID: "ABC-123"))
        }

        /// `key=` supplies an empty value rather than omitting the parameter, so
        /// it parses and is rejected later by key validation. XMenuBarCtl and Droppy
        /// both emit this shape, so it must not be treated as malformed.
        @Test("An empty key is present, not absent", arguments: [
            ("xmenubar://set?key=&value=true", SettingsURIRoute.set(key: "", value: "true", displayUUID: nil)),
            ("xmenubar://toggle?key=", .toggle(key: "", displayUUID: nil)),
        ])
        func emptyKeyIsNotMalformed(uri: String, expected: SettingsURIRoute) throws {
            #expect(try parse(uri).route == expected)
        }
    }

    @Suite("toggle")
    struct Toggle {
        @Test("Key produces a toggle route")
        func withKey() throws {
            #expect(try parse("xmenubar://toggle?key=autoRehide").route
                == .toggle(key: "autoRehide", displayUUID: nil))
        }
    }

    @Suite("get")
    struct Get {
        @Test("All parameters are captured")
        func allParameters() throws {
            #expect(try parse("xmenubar://get?key=all&callback=droppy://xmenubar-response&broadcast=true&requestId=42").route
                == .get(
                    key: "all",
                    displayUUID: nil,
                    callback: "droppy://xmenubar-response",
                    broadcast: true,
                    requestId: "42"
                ))
        }

        /// `get` never reports malformed: every parameter is optional.
        @Test("A bare get is well formed")
        func bareGet() throws {
            #expect(try parse("xmenubar://get").route
                == .get(key: nil, displayUUID: nil, callback: nil, broadcast: false, requestId: nil))
        }

        @Test("broadcast is true only for exactly \"true\"", arguments: [
            ("xmenubar://get?broadcast=true", true),
            ("xmenubar://get?broadcast=TRUE", false),
            ("xmenubar://get?broadcast=1", false),
            ("xmenubar://get", false),
        ])
        func broadcast(uri: String, expected: Bool) throws {
            guard case let .get(_, _, _, broadcast, _) = try parse(uri).route else {
                Issue.record("Expected a get route for \(uri)")
                return
            }
            #expect(broadcast == expected)
        }

        @Test("Only get?key=version is a version query", arguments: [
            ("xmenubar://get?key=version", true),
            ("xmenubar://get?key=all", false),
            ("xmenubar://set?key=version&value=1", false),
        ])
        func versionQuery(uri: String, expected: Bool) throws {
            #expect(try parse(uri).isVersionQuery == expected)
        }
    }

    @Suite("Routing")
    struct Routing {
        @Test("authorize is its own route")
        func authorize() throws {
            #expect(try parse("xmenubar://authorize").route == .authorize)
        }

        @Test("Every action round-trips from its raw value", arguments: SettingsURIAction.allCases)
        func actionRoundTrip(action: SettingsURIAction) throws {
            #expect(try parse("xmenubar://\(action.rawValue)").route == .action(action))
        }

        @Test("Unknown and empty hosts are unrecognized", arguments: [
            ("xmenubar://not-a-real-host", "not-a-real-host"),
            ("xmenubar://", ""),
        ])
        func unrecognized(uri: String, host: String) throws {
            #expect(try parse(uri).route == .unrecognized(host: host))
        }

        @Test("Hosts are matched case-insensitively")
        func caseInsensitiveHost() throws {
            #expect(try parse("xmenubar://SET?key=a&value=b").route
                == .set(key: "a", value: "b", displayUUID: nil))
            #expect(try parse("xmenubar://Toggle-Hidden").route == .action(.toggleHidden))
        }
    }

    @Suite("Authorization surface")
    struct Authorization {
        /// Incomplete settings URLs must not be able to raise an approval
        /// dialog, so they are rejected before the authorization gate.
        @Test("Missing required parameters yield malformed", arguments: [
            ("xmenubar://set", "set"),
            ("xmenubar://set?key=autoRehide", "set"),
            ("xmenubar://set?value=true", "set"),
            ("xmenubar://toggle", "toggle"),
        ])
        func malformed(uri: String, host: String) throws {
            #expect(try parse(uri).route == .malformed(host: host))
        }

        @Test("Only settings routes pass through the gate", arguments: [
            ("xmenubar://set", true),
            ("xmenubar://authorize", true),
            ("xmenubar://toggle-hidden", false),
            ("xmenubar://bogus", false),
        ])
        func requiresAuthorization(uri: String, expected: Bool) throws {
            #expect(try parse(uri).requiresAuthorization == expected)
        }

        @Test("bundleId override is captured, empty is ignored", arguments: [
            ("xmenubar://set?key=a&value=b&bundleId=com.example", "com.example"),
            ("xmenubar://set?key=a&value=b&bundleId=", nil),
            ("xmenubar://set?key=a&value=b", nil),
        ])
        func bundleIdOverride(uri: String, expected: String?) throws {
            #expect(try parse(uri).bundleIdOverride == expected)
        }
    }

    /// The parser is total: any URL yields a request and nothing traps.
    @Test("Parsing is total over awkward input", arguments: [
        "xmenubar://set?key=a&value=b&key=c",
        "xmenubar://set?key=%00&value=%FF",
        "xmenubar://get?callback=javascript:alert(1)",
        "xmenubar://toggle?key=" + String(repeating: "x", count: 8192),
        "xmenubar://set?=&=&=",
        "xmenubar://%20",
        "xmenubar://get?key=a#fragment",
    ])
    func parsingIsTotal(uri: String) {
        guard let url = URL(string: uri) else { return }
        _ = SettingsURIParser.parse(url)
    }
}
