import Flutter
import UIKit
import Foundation

class SecurityPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.faster.app/security",
            binaryMessenger: registrar.messenger()
        )
        let instance = SecurityPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkIntegrity":
            result(checkIntegrity())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkIntegrity() -> [String: Any] {
        return [
            "isRooted": false,
            "isJailbroken": isDeviceJailbroken(),
            "isEmulator": isRunningOnEmulator(),
            "isDebugger": isDebuggerAttached()
        ]
    }

    private func isDeviceJailbroken() -> Bool {
        if hasJailbreakPaths() { return true }
        if canWriteOutsideSandbox() { return true }
        if canFork() { return true }
        return false
    }

    private func hasJailbreakPaths() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/stash",
            "/usr/libexec/ssh-keysign",
            "/jb/lz2",
            "/jb/offsets.plist",
            "/usr/bin/ssh"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func canWriteOutsideSandbox() -> Bool {
        let path = "/private/" + UUID().uuidString
        do {
            try "test".write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    private func canFork() -> Bool {
        let pid = fork()
        if pid == 0 { exit(0) }
        if pid > 0 {
            kill(pid, SIGKILL)
            waitpid(pid, nil, 0)
            return true
        }
        return false
    }

    private func isRunningOnEmulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let errno = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        return errno == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
