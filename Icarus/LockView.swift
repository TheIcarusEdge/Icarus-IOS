import CryptoKit
import LocalAuthentication
import Security
import SwiftUI

enum Passcode {
    private static let account = "icarus.passcode"

    private static func hash(_ code: String) -> Data {
        Data(SHA256.hash(data: Data(("icarus:" + code).utf8)))
    }

    static var isSet: Bool { read() != nil }

    static func verify(_ code: String) -> Bool { read() == hash(code) }

    static func save(_ code: String) {
        clear()
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: hash(code),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func clear() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }

    private static func read() -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
}

struct LockView: View {
    @Environment(\.style) private var s
    let onUnlock: () -> Void

    private enum Mode { case unlock, create, confirm }
    @State private var mode: Mode = Passcode.isSet ? .unlock : .create
    @State private var digits = ""
    @State private var first = ""
    @State private var failed = false

    private let length = 4

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 120)
            Text("ICARUS").font(s.f(15, .bold)).tracking(6).foregroundStyle(s.p.acc)
            Text(prompt).font(s.f(15)).foregroundStyle(failed ? s.p.red : s.p.dim).padding(.top, 12)
            Spacer().frame(height: 120)
            HStack(spacing: 28) {
                ForEach(0..<length, id: \.self) { i in
                    Rectangle()
                        .fill(i < digits.count ? s.p.acc : .clear)
                        .overlay(Rectangle().stroke(s.p.acc, lineWidth: 1.5))
                        .frame(width: 12, height: 12)
                }
            }
            if mode == .unlock {
                Button("Use Face ID") { biometric() }
                    .font(s.f(14)).underline().foregroundStyle(s.p.dim)
                    .frame(minHeight: 44).padding(.top, 20)
            }
            Spacer()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "del"], id: \.self) { k in
                    key(k)
                }
            }
            .padding(.horizontal, 32).padding(.bottom, 40)
        }
        .onAppear { if mode == .unlock { biometric() } }
    }

    private var prompt: String {
        if failed { return mode == .confirm ? "Codes didn't match. Try again." : "Wrong passcode." }
        switch mode {
        case .unlock: return "Enter passcode"
        case .create: return "Create a passcode"
        case .confirm: return "Confirm passcode"
        }
    }

    @ViewBuilder private func key(_ k: String) -> some View {
        if k.isEmpty {
            Color.clear.frame(height: 64)
        } else {
            Button { press(k) } label: {
                Group {
                    if k == "del" { Image(systemName: "arrow.left").font(.system(size: 24)) }
                    else { Text(k).font(s.f(32)) }
                }
                .foregroundStyle(s.p.text)
                .frame(maxWidth: .infinity, minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(k == "del" ? "Delete" : k)
        }
    }

    private func press(_ k: String) {
        failed = false
        if k == "del" { if !digits.isEmpty { digits.removeLast() }; return }
        guard digits.count < length else { return }
        digits += k
        guard digits.count == length else { return }
        let code = digits
        digits = ""
        switch mode {
        case .unlock:
            if Passcode.verify(code) { onUnlock() } else { failed = true }
        case .create:
            first = code
            mode = .confirm
        case .confirm:
            if code == first { Passcode.save(code); onUnlock() }
            else { failed = true; first = ""; mode = .create }
        }
    }

    private func biometric() {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Icarus") { ok, _ in
            if ok { DispatchQueue.main.async { onUnlock() } }
        }
    }
}
