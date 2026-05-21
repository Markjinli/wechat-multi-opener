import Foundation

@MainActor
class WeChatManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasOriginalWeChat = false
    @Published var wechatCopies: [Int] = []
    @Published var isProcessing = false
    @Published var progressMessage = ""
    @Published var errorMessage = ""

    private var password: String?
    private let basePath = "/Applications"
    private let originalName = "WeChat.app"

    var totalInstances: Int { (hasOriginalWeChat ? 1 : 0) + wechatCopies.count }

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

    func scanWeChat() {
        hasOriginalWeChat = FileManager.default.fileExists(atPath: "\(basePath)/\(originalName)")
        wechatCopies = []
        for i in 2...99 {
            if FileManager.default.fileExists(atPath: "\(basePath)/WeChat\(i).app") {
                wechatCopies.append(i)
            }
        }
    }

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

    private func findNextAvailableNumber() -> Int {
        var num = 2
        while wechatCopies.contains(num) || FileManager.default.fileExists(atPath: "\(basePath)/WeChat\(num).app") {
            num += 1
        }
        return num
    }
}
