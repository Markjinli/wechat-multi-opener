import Foundation
import AppKit

@MainActor
class WeChatManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasOriginalWeChat = false
    @Published var wechatCopies: [Int] = []
    @Published var isProcessing = false
    @Published var progressMessage = ""
    @Published var errorMessage = ""

    @Published var isOriginalRunning = false
    @Published var runningStatus: [Int: Bool] = [:]

    private var password: String?
    private let basePath = "/Applications"
    private let originalName = "WeChat.app"

    var totalInstances: Int { (hasOriginalWeChat ? 1 : 0) + wechatCopies.count }

    // MARK: - Auth

    func verifyPassword(_ pw: String) async -> Bool {
        let pwCopy = pw
        let result = await Task.detached {
            SudoManager.verify(password: pwCopy)
        }.value

        if result {
            self.password = pw
            self.isAuthenticated = true
            scanWeChat()
        }
        return result
    }

    // MARK: - Scan

    func scanWeChat() {
        hasOriginalWeChat = FileManager.default.fileExists(atPath: "\(basePath)/\(originalName)")
        wechatCopies = []
        for i in 2...99 {
            if FileManager.default.fileExists(atPath: "\(basePath)/WeChat\(i).app") {
                wechatCopies.append(i)
            }
        }
        refreshRunningStatus()
    }

    // MARK: - Running Status

    func refreshRunningStatus() {
        isOriginalRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.path == "\(basePath)/\(originalName)"
        }

        var status: [Int: Bool] = [:]
        for num in wechatCopies {
            status[num] = NSWorkspace.shared.runningApplications.contains {
                $0.bundleURL?.path == "\(basePath)/WeChat\(num).app"
            }
        }
        runningStatus = status
    }

    // MARK: - Create

    func createCopies(count: Int) async {
        guard let password = password else { return }
        isProcessing = true
        errorMessage = ""

        var created = 0
        while created < count {
            let num = findNextAvailableNumber()
            progressMessage = "正在创建 WeChat\(num).app (\(created + 1)/\(count))..."

            let pw = password
            let success = await Task.detached {
                SudoManager.createCopy(num: num, password: pw)
            }.value

            if success {
                created += 1
            } else {
                errorMessage = "创建 WeChat\(num).app 失败，请检查权限或磁盘空间"
                break
            }
        }

        scanWeChat()
        isProcessing = false
        progressMessage = ""
    }

    // MARK: - Fix

    func fixAllCopies() async {
        guard let password = password, !wechatCopies.isEmpty else { return }
        isProcessing = true
        errorMessage = ""

        for (index, num) in wechatCopies.enumerated() {
            progressMessage = "正在修复 WeChat\(num).app (\(index + 1)/\(wechatCopies.count))..."

            let pw = password
            let success = await Task.detached {
                SudoManager.fixCopy(num: num, password: pw)
            }.value

            if !success {
                errorMessage = "修复 WeChat\(num).app 失败"
                break
            }
        }

        isProcessing = false
        progressMessage = ""
    }

    // MARK: - Delete

    func deleteCopy(num: Int) async {
        guard let password = password else { return }
        isProcessing = true
        progressMessage = "正在删除 微信\(num)..."

        let pw = password
        let _ = await Task.detached {
            SudoManager.deleteCopy(num: num, password: pw)
        }.value

        // 以实际结果为准：刷新后如果 app 已不在，则视为成功
        scanWeChat()
        if wechatCopies.contains(num) {
            errorMessage = "删除 微信\(num) 失败，请重试"
        }

        isProcessing = false
        progressMessage = ""
    }

    // MARK: - Private

    private func findNextAvailableNumber() -> Int {
        var num = 2
        while wechatCopies.contains(num) || FileManager.default.fileExists(atPath: "\(basePath)/WeChat\(num).app") {
            num += 1
        }
        return num
    }
}
