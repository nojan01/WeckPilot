#!/usr/bin/env swift
//
// WeckPilotWakeHelper
// macOS LaunchDaemon helper that schedules system wake events via pmset.
//
// This helper is triggered by launchd when the schedule file changes.
// It reads the next alarm time and uses pmset to wake the Mac from sleep.
//

import Foundation

// MARK: - Configuration

let sharedDir = "/Users/Shared/WeckPilot"
let schedulePath = "\(sharedDir)/schedule.json"
let statePath = "\(sharedDir)/state.json"
let logPath = "\(sharedDir)/helper.log"

let assertLabel = "de.little-tools.weckpilot.wake-assert"
let assertPlistPath = "/Library/LaunchDaemons/\(assertLabel).plist"

// MARK: - Data Models

struct Schedule: Codable {
    let nextWake: String?      // ISO 8601: "2026-02-12T06:59:00"
    let enabled: Bool
    let alarmTime: String?     // Original alarm time: "07:00"
    let label: String?         // Alarm label
}

struct HelperState: Codable {
    var lastScheduledWake: String?   // pmset format datetime
    var lastScheduledType: String?   // "wakeorpoweron"
}

// MARK: - Logging

func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = formatter.string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"
    
    // Print to stdout (captured by launchd)
    print(logMessage, terminator: "")
    
    // Also write to log file
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: sharedDir) {
        try? fileManager.createDirectory(atPath: sharedDir, withIntermediateDirectories: true)
    }
    
    if let data = logMessage.data(using: .utf8) {
        if fileManager.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            fileManager.createFile(atPath: logPath, contents: data)
        }
    }
    
    // Trim log file if too large (>1MB)
    if let attrs = try? fileManager.attributesOfItem(atPath: logPath),
       let size = attrs[.size] as? Int, size > 1_048_576 {
        try? "".write(toFile: logPath, atomically: true, encoding: .utf8)
        log("Log file trimmed (was \(size) bytes)")
    }
}

// MARK: - State Management

func readState() -> HelperState {
    guard let data = FileManager.default.contents(atPath: statePath),
          let state = try? JSONDecoder().decode(HelperState.self, from: data) else {
        return HelperState()
    }
    return state
}

func saveState(_ state: HelperState) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(state) {
        try? data.write(to: URL(fileURLWithPath: statePath))
    }
}

// MARK: - pmset Operations

/// Cancel a previously scheduled wake event
func cancelWake(type: String, datetime: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["schedule", "cancel", type, datetime]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            log("Cancelled wake event: \(type) \(datetime)")
        } else {
            log("Cancel failed (may not exist): \(type) \(datetime) - \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    } catch {
        log("Error cancelling wake: \(error)")
    }
}

/// Schedule a new wake event
func scheduleWake(datetime: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["schedule", "wakeorpoweron", datetime]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            log("Scheduled wake: wakeorpoweron \(datetime)")
            return true
        } else {
            log("Schedule failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            return false
        }
    } catch {
        log("Error scheduling wake: \(error)")
        return false
    }
}

// MARK: - Wake Assertion Job
//
// A pmset wake is often only a short "dark wake": without a power assertion
// the Mac goes back to sleep after ~30 seconds and the display stays off.
// To fix this we install a launchd job with a StartCalendarInterval at the
// wake time that runs `caffeinate -d -i -u -t 300`. launchd runs calendar
// jobs that were missed during sleep as soon as the Mac wakes, so this keeps
// the system awake for 5 minutes and turns the display on.

@discardableResult
func runLaunchctl(_ args: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
    } catch {
        return (-1, "\(error)")
    }
}

/// Remove the wake assertion launchd job (if present)
func removeAssertJob() {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: assertPlistPath) {
        runLaunchctl(["unload", assertPlistPath])
        try? fileManager.removeItem(atPath: assertPlistPath)
        log("Removed wake assertion job")
    } else {
        // In case the job is loaded but the file is gone
        runLaunchctl(["remove", assertLabel])
    }
}

/// Install a launchd job that keeps the Mac awake at the scheduled wake time
func installAssertJob(for date: Date) {
    let calendar = Calendar.current
    let comps = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
    guard let month = comps.month, let day = comps.day,
          let hour = comps.hour, let minute = comps.minute else {
        log("Cannot extract date components for assertion job")
        return
    }

    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>\(assertLabel)</string>
        <key>ProgramArguments</key>
        <array>
            <string>/usr/bin/caffeinate</string>
            <string>-d</string>
            <string>-i</string>
            <string>-u</string>
            <string>-t</string>
            <string>300</string>
        </array>
        <key>StartCalendarInterval</key>
        <dict>
            <key>Month</key>
            <integer>\(month)</integer>
            <key>Day</key>
            <integer>\(day)</integer>
            <key>Hour</key>
            <integer>\(hour)</integer>
            <key>Minute</key>
            <integer>\(minute)</integer>
        </dict>
        <key>RunAtLoad</key>
        <false/>
    </dict>
    </plist>
    """

    do {
        try plist.write(toFile: assertPlistPath, atomically: true, encoding: .utf8)
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o644]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: assertPlistPath)

        let result = runLaunchctl(["load", assertPlistPath])
        if result.status == 0 {
            log("Installed wake assertion job for \(month)/\(day) \(String(format: "%02d:%02d", hour, minute)) (caffeinate 300s)")
        } else {
            log("Failed to load wake assertion job: \(result.output)")
        }
    } catch {
        log("Error writing assertion plist: \(error)")
    }
}

/// List current scheduled wake events
func listScheduledEvents() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g", "sched"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    } catch {
        return "Error: \(error)"
    }
}

// MARK: - Date Formatting

func parseDatetime(_ isoString: String) -> Date? {
    // Try ISO 8601 with seconds
    let formats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm"
    ]
    
    for format in formats {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        if let date = formatter.date(from: isoString) {
            return date
        }
    }
    return nil
}

func formatForPmset(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}

// MARK: - Main Logic

func main() {
    log("========================================")
    log("WeckPilot Wake Helper started")
    
    // Ensure shared directory exists with proper permissions
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: sharedDir) {
        try? fileManager.createDirectory(atPath: sharedDir, withIntermediateDirectories: true)
        // Make writable by all users so the Tauri app can write schedule.json
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o777]
        try? fileManager.setAttributes(attrs, ofItemAtPath: sharedDir)
    }
    
    // Read current state (previous schedule info)
    var state = readState()
    
    // Cancel previous wake event if we had one
    if let lastWake = state.lastScheduledWake, let lastType = state.lastScheduledType {
        cancelWake(type: lastType, datetime: lastWake)
        state.lastScheduledWake = nil
        state.lastScheduledType = nil
        saveState(state)
    }
    
    // Remove previous wake assertion job (re-installed below if needed)
    removeAssertJob()
    
    // Read schedule file
    guard fileManager.fileExists(atPath: schedulePath) else {
        log("No schedule file found at \(schedulePath)")
        saveState(state)
        log("Done (no schedule)")
        return
    }
    
    guard let data = fileManager.contents(atPath: schedulePath),
          let schedule = try? JSONDecoder().decode(Schedule.self, from: data) else {
        log("Invalid schedule file format")
        saveState(state)
        return
    }
    
    // Check if scheduling is enabled
    guard schedule.enabled else {
        log("Schedule is disabled")
        saveState(state)
        log("Done (disabled)")
        return
    }
    
    // Parse next wake time
    guard let nextWakeStr = schedule.nextWake else {
        log("No next wake time in schedule")
        saveState(state)
        return
    }
    
    guard let wakeDate = parseDatetime(nextWakeStr) else {
        log("Invalid datetime format: \(nextWakeStr)")
        return
    }
    
    // Schedule wake 1 minute early to give system time to fully wake
    var earlyWakeDate = wakeDate.addingTimeInterval(-60)
    
    // If the early wake is already past but the alarm itself is still in the
    // future, clamp to a few seconds from now instead of skipping entirely
    let now = Date()
    if earlyWakeDate <= now && wakeDate > now.addingTimeInterval(15) {
        earlyWakeDate = now.addingTimeInterval(15)
        log("Early wake in the past, clamped to \(earlyWakeDate)")
    }
    
    // Only schedule if in the future
    guard earlyWakeDate > now else {
        log("Wake time is in the past: \(nextWakeStr)")
        saveState(state)
        return
    }
    
    // Schedule the wake event
    let pmsetDate = formatForPmset(earlyWakeDate)
    let success = scheduleWake(datetime: pmsetDate)
    
    if success {
        state.lastScheduledWake = pmsetDate
        state.lastScheduledType = "wakeorpoweron"
        saveState(state)
        
        let label = schedule.label ?? schedule.alarmTime ?? "alarm"
        log("Wake scheduled for \(pmsetDate) (alarm: \(label) at \(schedule.alarmTime ?? nextWakeStr))")
        
        // Keep the Mac awake after the pmset wake (prevents fall-back to sleep
        // before the alarm fires) and turn the display on
        installAssertJob(for: earlyWakeDate)
    }
    
    // Show current schedule
    let events = listScheduledEvents()
    log("Current pmset schedule:\n\(events)")
    
    log("Done")
}

// Run
main()
