import SwiftUI
import SteadfastCore

private enum Theme {
    static let ink = Color(hex: "#1a1a1f")
    static let ink2 = Color(hex: "#3a3a40")
    static let ink3 = Color(hex: "#62626a")
    static let ink4 = Color(hex: "#9a9aa1")
    static let hair = Color.black.opacity(0.07)
    static let hair2 = Color.black.opacity(0.12)
    static let surface = Color(hex: "#fdfdfb")
    static let surface2 = Color(hex: "#f5f3ee")
    static let background = Color(hex: "#f0ede5")
    static let green = Color(hex: "#2f7a52")
    static let greenLight = Color(hex: "#dfeee5")
    static let blue = Color(hex: "#2a5fd0")
    static let blueLight = Color(hex: "#e3eaf8")
    static let red = Color(hex: "#c0392f")
    static let redLight = Color(hex: "#f6e3df")
}

struct BlockmeRootView: View {
    @StateObject private var model = BlockmeModel()
    @State private var addDomainValue = ""

    var body: some View {
        UtilityWindowShell {
            ZStack {
                VStack(spacing: 0) {
                    if model.mode != .install && model.mode != .error {
                        StatusBlockView(model: model)
                    }

                    mainContent
                    FooterView(model: model)
                }

                if model.addSheetPresented {
                    AddDomainSheet(
                        value: $addDomainValue,
                        isSubmitting: model.isAddingDomain,
                        existingDomains: model.domains,
                        onCancel: {
                            addDomainValue = ""
                            model.addSheetPresented = false
                        },
                        onSubmit: { candidate in
                            model.addDomain(candidate)
                            if !model.addSheetPresented {
                                addDomainValue = ""
                            }
                        }
                    )
                }
            }
            .background(Theme.background)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            switch model.mode {
            case .install:
                InstallStateView(
                    isInstalling: model.isInstalling,
                    onInstall: model.installProtection
                )
            case .error:
                ErrorStateView(
                    model: model,
                    onRetry: model.retryConnection,
                    onReinstall: model.reinstallProtection
                )
            case .active, .empty:
                if let banner = model.banner {
                    BannerView(banner: banner, onDismiss: model.dismissBanner)
                }

                ListHeaderView(
                    count: model.domains.count,
                    onAdd: {
                        addDomainValue = ""
                        model.addSheetPresented = true
                    }
                )

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.hair2, lineWidth: 0.5)
                        )

                    if model.domains.isEmpty {
                        EmptyListView {
                            addDomainValue = ""
                            model.addSheetPresented = true
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(model.domains.enumerated()), id: \.element) { index, domain in
                                    DomainRowView(
                                        domain: domain,
                                        isLast: index == model.domains.count - 1
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }
}

struct UtilityWindowShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(width: 480, height: 600)
        .background(Color(hex: "#f6f4ee"))
    }
}

struct StatusBlockView: View {
    @ObservedObject var model: BlockmeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(iconRingColor, lineWidth: 0.5)
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: shieldSymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        PulseDot(color: Theme.green)
                        Text("Protection is active")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    Text("Enforced in the background. Continues even when this window is closed.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }

            Divider()
                .overlay(Theme.hair)
                .padding(.top, 12)

            HStack(spacing: 22) {
                StatusKV(label: "Service", value: "Running")
                StatusKV(label: "Blocked", value: "\(model.domains.count)")
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surface)
                .overlay(alignment: .leading) {
                    LinearGradient(
                        colors: [washColor, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 90)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.hair2, lineWidth: 0.5)
                )
        )
        .padding(.top, 14)
        .padding(.horizontal, 14)
    }

    private var shieldSymbol: String {
        "checkmark.shield.fill"
    }

    private var iconColor: Color {
        Theme.green
    }

    private var washColor: Color {
        Theme.greenLight
    }

    private var iconRingColor: Color {
        Color(red: 47 / 255, green: 122 / 255, blue: 82 / 255).opacity(0.22)
    }
}

struct StatusKV: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.ink4)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink2)
        }
    }
}

struct PulseDot: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 2.2 : 1)
                .opacity(animate ? 0 : 0.35)
                .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false), value: animate)
        }
        .onAppear { animate = true }
    }
}

struct BannerView: View {
    let banner: BlockmeModel.BannerData
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(banner.tone == .success ? Theme.green : Theme.red)
            Text(banner.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.ink4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(banner.tone == .success ? Theme.green.opacity(0.18) : Theme.red.opacity(0.18), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }
}

struct ListHeaderView: View {
    let count: Int
    let onAdd: () -> Void

    var body: some View {
        HStack {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("Blocklist")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundStyle(Theme.ink4)
                Text("\(count) \(count == 1 ? "domain" : "domains")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink4)
            }

            Spacer()

            PillButton(label: "Add Domain", kind: .primary, systemImage: "plus", action: onAdd)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

struct DomainRowView: View {
    let domain: String
    let isLast: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(chipBackground)
                .frame(width: 24, height: 24)
                .overlay {
                    Text(String(domain.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(chipForeground)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(chipForeground.opacity(0.14), lineWidth: 0.5)
                )

            Text(domain)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            blockedTag
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Theme.hair)
                    .frame(height: 0.5)
            }
        }
    }

    private var blockedTag: some View {
        Text("Blocked")
            .font(.system(size: 9.5, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(Theme.ink4)
    }

    private var chipForeground: Color {
        chipPalette.0
    }

    private var chipBackground: Color {
        chipPalette.1
    }

    private var chipPalette: (Color, Color) {
        let palettes: [(Color, Color)] = [
            (Color(hex: "#2f7a52"), Color(hex: "#dfeee5")),
            (Color(hex: "#2a5fd0"), Color(hex: "#e3eaf8")),
            (Color(hex: "#a04a8a"), Color(hex: "#f1e3ee")),
            (Color(hex: "#a06900"), Color(hex: "#f5e9cc")),
            (Color(hex: "#6a4ca8"), Color(hex: "#e8e3f5")),
            (Color(hex: "#3b6e8a"), Color(hex: "#dce8f0")),
            (Color(hex: "#a04330"), Color(hex: "#f3e0d9")),
        ]
        var hash = 0
        for scalar in domain.unicodeScalars {
            hash = (hash * 31 + Int(scalar.value)) & 0x7fffffff
        }
        return palettes[hash % palettes.count]
    }
}

struct EmptyListView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface2)
                    .frame(width: 56, height: 56)
                Image(systemName: "shield")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
            Text("Your blocklist is empty")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Protection is active and watching. Add a domain to start enforcing.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
                .lineSpacing(3)

            PillButton(label: "Add your first domain", kind: .primary, systemImage: "plus", action: onAdd)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
    }
}

struct FooterView: View {
    @ObservedObject var model: BlockmeModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.mode {
            case .install:
                footerBullet(color: Theme.ink4)
                Text("Service not installed")
                    .foregroundStyle(Theme.ink4)
            case .error:
                footerBullet(color: Theme.red)
                Text("Disconnected")
                    .foregroundStyle(Theme.red)
                Spacer()
            case .active, .empty:
                PulseDot(color: Theme.green)
                Text("Service running")
                    .foregroundStyle(Theme.green)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                    Text("Protected")
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hair2)
                .frame(height: 0.5)
        }
    }

    private func footerBullet(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

struct InstallStateView: View {
    let isInstalling: Bool
    let onInstall: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .frame(width: 76, height: 76)
                    .shadow(color: Theme.blue.opacity(0.28), radius: 18, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Theme.blue.opacity(0.18), lineWidth: 0.5)
                    )
                Image(systemName: "shield")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Theme.blue)
            }

            VStack(spacing: 8) {
                Text("Install background protection")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Blockme installs a small system service that enforces your blocklist even when this window is closed. You’ll be asked for administrator approval once.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .lineSpacing(3)
            }

            Button(action: onInstall) {
                HStack(spacing: 8) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(isInstalling ? "Installing…" : "Install Protection")
                }
                .frame(height: 32)
                .padding(.horizontal, 22)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isInstalling)
            .padding(.top, 4)

            Text("Requires admin authentication · macOS 13 or later")
                .font(.system(size: 10.5, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(Theme.ink4)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [Theme.blueLight, .clear], center: .top, startRadius: 20, endRadius: 260)
        )
        .padding(.horizontal, 36)
    }
}

struct ErrorStateView: View {
    @ObservedObject var model: BlockmeModel
    let onRetry: () -> Void
    let onReinstall: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .frame(width: 70, height: 70)
                    .shadow(color: Theme.red.opacity(0.30), radius: 16, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.red.opacity(0.18), lineWidth: 0.5)
                    )
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.red)
            }

            VStack(spacing: 6) {
                Text("Protection is not running")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("The background service stopped responding. Your blocklist is preserved, but domains are not currently being enforced.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                Button("Reinstall service", action: onReinstall)
                    .buttonStyle(SecondaryActionButtonStyle(height: 30))
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        if model.isRetrying {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(model.isRetrying ? "Retrying…" : "Retry connection")
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(model.isRetrying)
            }
            .padding(.top, 4)

            Text(model.errorDetailLabel)
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .foregroundStyle(Theme.red)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [Theme.redLight, .clear], center: .top, startRadius: 20, endRadius: 260)
        )
        .padding(.horizontal, 36)
    }
}

struct AddDomainSheet: View {
    @Binding var value: String
    let isSubmitting: Bool
    let existingDomains: [String]
    let onCancel: () -> Void
    let onSubmit: (String) -> Void
    @State private var validationMessage = ""

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isSubmitting {
                        onCancel()
                    }
                }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.redLight)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: "shield")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.red)
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Add domain to blocklist")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text("Takes effect immediately, system-wide.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .padding(.bottom, 12)

                    HStack(spacing: 8) {
                        Text("https://")
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(Theme.ink4)
                        TextField("instagram.com", text: $value)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                            .disabled(isSubmitting)
                        if let preview = parsedPreview {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(preview)
                            }
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Theme.ink4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(validationMessage.isEmpty ? Theme.hair2 : Theme.red, lineWidth: validationMessage.isEmpty ? 0.5 : 1.5)
                    )

                    HStack(spacing: 6) {
                        if !validationMessage.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.red)
                        }
                        Text(validationMessage.isEmpty ? "Enter a domain such as instagram.com. Subdomains are blocked automatically." : validationMessage)
                            .font(.system(size: 11.5))
                            .foregroundStyle(validationMessage.isEmpty ? Theme.ink3 : Theme.red)
                    }
                    .padding(.top, 8)
                    .frame(minHeight: 16, alignment: .leading)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)

                HStack(spacing: 8) {
                    Spacer()
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(minWidth: 96)
                    }
                    .buttonStyle(SecondaryActionButtonStyle(height: 32))
                    .disabled(isSubmitting)
                    Button(action: {
                        submit()
                    }) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Applying…" : "Add to blocklist")
                        }
                        .frame(minWidth: 132)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.surface2)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.hair)
                        .frame(height: 0.5)
                }
            }
            .frame(width: 380)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 24, y: 12)
            .padding(.top, 64)
        }
    }

    private var parsedPreview: String? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let lowercase = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidate = lowercase.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        guard candidate != lowercase else { return nil }
        return candidate.replacingOccurrences(of: "/", with: "")
    }

    private func submit() {
        guard !isSubmitting else { return }
        do {
            let normalized = try DomainNormalizer.normalize(value)
            guard !existingDomains.contains(normalized) else {
                validationMessage = "\(normalized) is already in your blocklist."
                return
            }
            validationMessage = ""
            onSubmit(normalized)
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}

struct PillButton: View {
    enum Kind {
        case primary
        case ghost
    }

    let label: String
    let kind: Kind
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11)
            .frame(height: 24)
        }
        .buttonStyle(kind == .primary ? AnyButtonStyle(PrimaryPillButtonStyle()) : AnyButtonStyle(GhostPillButtonStyle()))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(.white.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.hair2, lineWidth: 0.5)
            )
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct GhostPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 11)
            .background(Color.black.opacity(configuration.isPressed ? 0.08 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
