import Foundation

enum SudoManager {

    static func verify(password: String) -> Bool {
        runCommand("echo ok", password: password).success
    }

    static func createCopy(num: Int, password: String) -> Bool {
        let script = """
        set -e
        SRC="/Applications/WeChat.app"
        DST="/Applications/WeChat\(num).app"
        BID="com.tencent.xinWeChat\(num)"
        LABEL="微信\(num)"

        # 1. 复制应用
        cp -R "$SRC" "$DST"

        # 2. 修改 Bundle ID
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BID" "$DST/Contents/Info.plist"

        # 3. 修改 Info.plist 显示名称
        /usr/libexec/PlistBuddy -c "Set :CFBundleName $LABEL" "$DST/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $LABEL" "$DST/Contents/Info.plist"

        # 4. 修改所有本地化文件中的显示名称（覆盖 "微信"）
        find "$DST/Contents/Resources" -name "InfoPlist.strings" | while read f; do
            plutil -convert xml1 "$f" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $LABEL" "$f" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $LABEL" "$f" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Set :CFBundleName $LABEL" "$f" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleName string $LABEL" "$f" 2>/dev/null || true
        done

        # 5. 清除扩展属性
        xattr -cr "$DST"

        # 6. 重新签名
        codesign --force --deep --sign - "$DST" 2>/dev/null || true

        # 7. 修复权限
        chown -R "$(whoami)" "$DST"
        """
        return runScript(script, password: password)
    }

    static func fixCopy(num: Int, password: String) -> Bool {
        let script = """
        set -e
        DST="/Applications/WeChat\(num).app"
        BID="com.tencent.xinWeChat\(num)"
        LABEL="微信\(num)"

        # 1. 修改 Bundle ID
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BID" "$DST/Contents/Info.plist"

        # 2. 修改 Info.plist 显示名称
        /usr/libexec/PlistBuddy -c "Set :CFBundleName $LABEL" "$DST/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $LABEL" "$DST/Contents/Info.plist"

        # 3. 修改所有本地化文件中的显示名称
        find "$DST/Contents/Resources" -name "InfoPlist.strings" | while read f; do
            plutil -convert xml1 "$f" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $LABEL" "$f" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $LABEL" "$f" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Set :CFBundleName $LABEL" "$f" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleName string $LABEL" "$f" 2>/dev/null || true
        done

        # 4. 清除扩展属性
        xattr -cr "$DST"

        # 5. 重新签名
        codesign --force --deep --sign - "$DST" 2>/dev/null || true

        # 6. 修复权限
        chown -R "$(whoami)" "$DST"
        """
        return runScript(script, password: password)
    }

    static func deleteCopy(num: Int, password: String) -> Bool {
        let script = """
        pkill -f "WeChat\(num).app" 2>/dev/null || true
        sleep 1
        rm -rf "/Applications/WeChat\(num).app"
        rm -rf "$HOME/Library/Containers/com.tencent.xinWeChat\(num)"
        """
        return runScript(script, password: password)
    }

    // MARK: - Private

    private static func runCommand(_ command: String, password: String) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-S", "-k", "/bin/bash", "-c", command]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()

            if let data = (password + "\n").data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            stdinPipe.fileHandleForWriting.closeFile()

            process.waitUntilExit()

            let output = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            return (process.terminationStatus == 0, process.terminationStatus == 0 ? output : err)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private static func runScript(_ script: String, password: String) -> Bool {
        let tempPath = "/tmp/.wechat_multi_\(ProcessInfo.processInfo.processIdentifier).sh"
        do {
            try script.write(toFile: tempPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempPath)
            let result = runCommand("bash '\(tempPath)'", password: password)
            try? FileManager.default.removeItem(atPath: tempPath)
            return result.success
        } catch {
            return false
        }
    }
}
