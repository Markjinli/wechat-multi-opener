import SwiftUI

extension Color {
    static let wechatGreen = Color(red: 7 / 255, green: 193 / 255, blue: 96 / 255)
}

extension ShapeStyle where Self == Color {
    static var wechatGreen: Color { .wechatGreen }
}

let appRepoURL = "https://github.com/Markjinli/wechat-multi-opener"

struct ContentView: View {
    @StateObject private var manager = WeChatManager()

    var body: some View {
        ZStack {
            if !manager.isAuthenticated {
                PasswordView(manager: manager)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                MainView(manager: manager)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }

            if manager.isProcessing {
                ProcessingOverlay(message: manager.progressMessage)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: manager.isAuthenticated)
        .animation(.easeInOut(duration: 0.2), value: manager.isProcessing)
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Password View

struct PasswordView: View {
    @ObservedObject var manager: WeChatManager
    @State private var password = ""
    @State private var isVerifying = false
    @State private var showError = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 6) {
                Text("微信多开助手开源版")
                    .font(.title.bold())
                Text("需要管理员权限以执行操作")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                SecureField("请输入开机密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .frame(width: 300, height: 32)
                    .focused($isFieldFocused)
                    .onSubmit { verify() }

                if showError {
                    Text("密码错误，请重试")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                Button {
                    verify()
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("验证")
                                .font(.body)
                        }
                    }
                    .frame(width: 300, height: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.wechatGreen)
                .disabled(password.isEmpty || isVerifying)
            }

            Spacer()

            FooterLink()
        }
        .frame(width: 520, height: 440)
        .onAppear { isFieldFocused = true }
        .animation(.easeInOut(duration: 0.25), value: showError)
    }

    private func verify() {
        guard !password.isEmpty else { return }
        isVerifying = true
        showError = false

        Task {
            let success = await manager.verifyPassword(password)
            isVerifying = false
            if !success {
                withAnimation { showError = true }
                password = ""
            }
        }
    }
}

// MARK: - Main View

struct MainView: View {
    @ObservedObject var manager: WeChatManager
    @State private var showInputDialog = false
    @State private var copyCount = 1
    @State private var deleteTarget: Int? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if manager.hasOriginalWeChat {
                wechatDetectedContent
            } else {
                noWeChatContent
            }
        }
        .frame(width: 520, height: 440)
        .sheet(isPresented: $showInputDialog) {
            countInputSheet
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let num = deleteTarget {
                    Task { await manager.deleteCopy(num: num) }
                }
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            if let num = deleteTarget, manager.runningStatus[num] == true {
                Text("微信\(num) 正在运行中，删除后将强制关闭并清除数据。确认删除？")
            } else if let num = deleteTarget {
                Text("确认删除 微信\(num)？相关数据将一并清除。")
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { !manager.errorMessage.isEmpty },
            set: { if !$0 { manager.errorMessage = "" } }
        )) {
            Button("确定") { manager.errorMessage = "" }
        } message: {
            Text(manager.errorMessage)
        }
        .task {
            while !Task.isCancelled {
                manager.refreshRunningStatus()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("微信多开助手开源版")
                    .font(.title3.weight(.semibold))
            }
            Spacer()

            if manager.wechatCopies.count > 0 {
                Button {
                    Task { await manager.fixAllCopies() }
                } label: {
                    Label("修复多开错误", systemImage: "wrench.and.screwdriver")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(manager.isProcessing)
            }

            Button {
                manager.scanWeChat()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(manager.isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Has WeChat

    private var wechatDetectedContent: some View {
        VStack(spacing: 0) {
            instanceList
            Spacer()
            actionButton
            footer
        }
    }

    private var instanceList: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Original
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.wechatGreen)
                    .frame(width: 10, height: 10)
                Text("微信")
                    .font(.body.weight(.medium))
                TagView(text: "原版", color: .wechatGreen)

                if manager.isOriginalRunning {
                    TagView(text: "运行中", color: .green)
                }

                Spacer()
            }

            // Copies
            ForEach(manager.wechatCopies, id: \.self) { num in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                    Text("微信\(num)")
                        .font(.body.weight(.medium))
                    TagView(text: "副本", color: .orange)

                    if manager.runningStatus[num] == true {
                        TagView(text: "运行中", color: .green)
                    }

                    Spacer()

                    Button {
                        deleteTarget = num
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.callout)
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.borderless)
                    .help("删除此副本")
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }

    private var actionButton: some View {
        Button {
            showInputDialog = true
        } label: {
            Label("一键多开微信", systemImage: "plus.circle.fill")
                .font(.body.weight(.semibold))
                .frame(width: 260, height: 46)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.wechatGreen)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("当前共 \(manager.totalInstances) 个微信实例")
                .font(.callout)
                .foregroundStyle(.secondary)
            FooterLink()
        }
        .padding(.top, 14)
        .padding(.bottom, 22)
    }

    // MARK: - No WeChat

    private var noWeChatContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("未检测到微信软件")
                    .font(.title3.weight(.semibold))
                Text("请先安装微信后再使用多开功能")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Button {
                if let url = URL(string: "macappstore://itunes.apple.com/app/id836500024") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("去 App Store 安装", systemImage: "arrow.down.circle.fill")
                    .font(.body.weight(.medium))
                    .frame(width: 240, height: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.wechatGreen)

            Spacer()

            FooterLink()
        }
    }

    // MARK: - Count Input Sheet

    private var countInputSheet: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("多开微信")
                    .font(.title3.weight(.semibold))
                Text("输入需要额外创建的微信数量")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Stepper {
                    Text("多开 **\(copyCount)** 个")
                        .font(.title3.weight(.medium))
                } onIncrement: {
                    copyCount = min(copyCount + 1, 10)
                } onDecrement: {
                    copyCount = max(copyCount - 1, 1)
                }
            }

            Text("将创建 \(copyCount) 个微信副本，加上原版共 \(manager.totalInstances + copyCount) 个实例")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("取消") {
                    showInputDialog = false
                }
                .keyboardShortcut(.cancelAction)
                .frame(width: 110, height: 36)

                Button("确定") {
                    showInputDialog = false
                    let count = copyCount
                    Task { await manager.createCopies(count: count) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Color.wechatGreen)
                .frame(width: 110, height: 36)
            }
        }
        .padding(32)
        .frame(width: 380)
    }
}

// MARK: - Shared Footer Link

struct FooterLink: View {
    var body: some View {
        Link(destination: URL(string: appRepoURL)!) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text("前往项目 GitHub 仓库")
            }
            .font(.callout)
            .foregroundStyle(Color.wechatGreen.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Processing Overlay

struct ProcessingOverlay: View {
    let message: String

    var body: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
