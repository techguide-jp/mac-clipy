#!/usr/bin/env swift
import AppKit
import Darwin
import Foundation

let environment = ProcessInfo.processInfo.environment
let bundleID = environment["BUNDLE_ID"] ?? "jp.techguide.macclipy"
let quitTimeoutSeconds = timeoutValue(named: "QUIT_TIMEOUT_SECONDS", defaultValue: 10)
let launchTimeoutSeconds = timeoutValue(named: "LAUNCH_TIMEOUT_SECONDS", defaultValue: 10)

func timeoutValue(named name: String, defaultValue: TimeInterval) -> TimeInterval {
    guard
        let rawValue = environment[name],
        let value = TimeInterval(rawValue),
        value > 0
    else {
        return defaultValue
    }

    return value
}

func runningApplications() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
}

func isRunning() -> Bool {
    !runningApplications().isEmpty
}

func waitForState(running expectedRunning: Bool, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() <= deadline {
        if isRunning() == expectedRunning {
            return true
        }

        Thread.sleep(forTimeInterval: 0.2)
    }

    return isRunning() == expectedRunning
}

func quitAndWait() -> Int32 {
    let applications = runningApplications()

    guard !applications.isEmpty else {
        print("==> No running app: \(bundleID)")
        return 0
    }

    print("==> Quit running app: \(bundleID)")
    for application in applications {
        _ = application.terminate()
    }

    guard waitForState(running: false, timeout: quitTimeoutSeconds) else {
        fputs("Timed out waiting for \(bundleID) to become stopped.\n", stderr)
        return 1
    }

    return 0
}

func waitRunning() -> Int32 {
    guard waitForState(running: true, timeout: launchTimeoutSeconds) else {
        fputs("Timed out waiting for \(bundleID) to become running.\n", stderr)
        return 1
    }

    return 0
}

func waitStopped() -> Int32 {
    guard waitForState(running: false, timeout: quitTimeoutSeconds) else {
        fputs("Timed out waiting for \(bundleID) to become stopped.\n", stderr)
        return 1
    }

    return 0
}

guard let command = CommandLine.arguments.dropFirst().first else {
    fputs("Usage: BUNDLE_ID=<bundle-id> scripts/app-lifecycle.swift {quit-and-wait|wait-running|wait-stopped}\n", stderr)
    exit(2)
}

switch command {
case "quit-and-wait":
    exit(quitAndWait())
case "wait-running":
    exit(waitRunning())
case "wait-stopped":
    exit(waitStopped())
default:
    fputs("Usage: BUNDLE_ID=<bundle-id> scripts/app-lifecycle.swift {quit-and-wait|wait-running|wait-stopped}\n", stderr)
    exit(2)
}
