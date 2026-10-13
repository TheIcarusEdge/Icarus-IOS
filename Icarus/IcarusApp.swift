import SwiftUI

@main
struct IcarusApp: App {
    @StateObject private var store = Store()
    @AppStorage("theme") private var theme = ThemeID.dark.rawValue
    @AppStorage("font") private var font = FontID.grotesk.rawValue
    @State private var unlocked = false
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            let style = Style(theme: ThemeID(rawValue: theme) ?? .dark,
                              fontID: FontID(rawValue: font) ?? .grotesk)
            ZStack {
                style.p.bg.ignoresSafeArea()
                if unlocked {
                    RootView(lock: { unlocked = false })
                } else {
                    LockView(onUnlock: { unlocked = true })
                }
            }
            .environment(\.style, style)
            .environmentObject(store)
            .preferredColorScheme(style.theme.scheme)
            .onChange(of: phase) { _, new in
                if new == .background { unlocked = false }
            }
        }
    }
}

struct RootView: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store
    @AppStorage("server") private var server = ""
    let lock: () -> Void

    private let tabs: [Store.Tab] = [.alerts, .chart, .watch, .swing, .trade]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(tabs, id: \.self) { t in
                    Button { store.tab = t } label: {
                        Text(t.rawValue)
                            .font(s.f(15, .semibold))
                            .foregroundStyle(store.tab == t ? s.p.text : s.p.dim)
                            .frame(height: 44)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(store.tab == t ? s.p.text : .clear).frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button { store.tab = .settings } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(store.tab == .settings ? s.p.text : s.p.dim)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .padding(.leading, 20).padding(.trailing, 8)
            Hairline()

            if store.offline {
                Text(server.isEmpty ? "Add the Icarus address in Settings."
                                    : "Can't reach Icarus. Check Tailscale and the address in Settings.")
                    .font(s.f(13, .semibold))
                    .foregroundStyle(s.p.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.vertical, 10)
            }

            Group {
                switch store.tab {
                case .alerts: AlertsView()
                case .chart: ChartTab()
                case .watch: WatchlistView()
                case .swing: SwingView()
                case .trade: TradingView()
                case .settings: SettingsView(lock: lock)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .foregroundStyle(s.p.text)
        .task(id: server) {
            while !Task.isCancelled {
                await store.refresh(server: server)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }
}

/// Every list screen: a vertical scroll with no indicators and pull-to-refresh.
struct Screen<Content: View>: View {
    @EnvironmentObject private var store: Store
    @AppStorage("server") private var server = ""
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.refresh(server: server) }
    }
}
