import Foundation
import SwiftUI

// MARK: - Client

struct API {
    let base: URL

    init?(_ server: String) {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        guard let u = URL(string: s) else { return nil }
        base = u
    }

    func get<T: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> T {
        var c = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: c.url!)
        req.timeoutInterval = 12
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let code = (resp as? HTTPURLResponse)?.statusCode, code >= 400 {
            throw HTTPError(code: code, path: path)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct HTTPError: LocalizedError {
    let code: Int
    let path: String
    var errorDescription: String? { "the server answered \(code) for /\(path)" }
}

// MARK: - Models (every field optional where the server can send null)

struct Health: Decodable { let ok: Bool? }

struct MobileAlerts: Decodable {
    let date: String?
    let rates: [String: Rate]?
    let alerts: [AlertRow]?
}

struct Rate: Decodable {
    let wins: Int
    let n: Int
}

struct AlertRow: Decodable, Identifiable {
    let id: String
    let origin: String
    let ticker: String
    let contract: String
    let cp: String?
    let time: String
    let entry: Double?
    let target: Double?
    let peak_pct: Double?
    let result: String
    let tags: [String]
}

struct WatchResp: Decodable { let items: [WatchItem]? }

struct WatchItem: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let price: Double?
    let change_pct: Double?
    let rel_to_spy_pct: Double?
    let vol_ratio: Double?
    let bucket: String?
}

struct BarsResp: Decodable { let bars: [Bar]? }

struct Bar: Decodable {
    let t: Double
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double?
    var date: Date { Date(timeIntervalSince1970: t / 1000) }
}

struct ContextResp: Decodable { let gex: Gex? }

struct Gex: Decodable {
    let call_wall: Double?
    let king_node: Double?
    let put_wall: Double?
    let gamma_flip: Double?
}

struct SwingResp: Decodable {
    let tracking: [SwingRow]?
    let resolved: [SwingRow]?
    let rollup: SwingRollup?
}

struct SwingRollup: Decodable {
    let posted: WinCount?
    let shadow: WinCount?
    let direction: [Split]?
    let method: [Split]?
    let regime: [Split]?
}
struct WinCount: Decodable { let n: Int; let wins: Int }
struct Split: Decodable { let k: String?; let n: Int; let w: Int }

struct SwingRow: Decodable, Identifiable {
    var id: String { "\(ticker)-\(date ?? "")-\(method ?? "")-\(strike ?? 0)" }
    let date: String?
    let ticker: String
    let direction: String?
    let method: String?
    let spot: Double?
    let target: Double?
    let invalid: Double?
    let strike: Double?
    let cp: String?
    let expiry: String?
    let entry_mid: Double?
    let peak_pct: Double?
    let min_pct: Double?
    let hit50: Int?
}

struct PositionsResp: Decodable { let positions: [Position]? }

struct Position: Decodable, Identifiable {
    var id: String { symbol + (opened_at_et ?? "") }
    let symbol: String
    let entry_premium: Double?
    let live_mark: Double?
    let unrealized_pct: Double?
    let unrealized_pnl: Double?
    let opened_at_et: String?
}

struct PerformanceResp: Decodable { let trades: [ClosedTrade]? }

struct ClosedTrade: Decodable, Identifiable {
    var id: String { symbol + (closed_at_et ?? "") }
    let symbol: String
    let closed_at_et: String?
    let entry_premium: Double?
    let exit_premium: Double?
    let pnl_pct: Double?
    let pnl_usd: Double?
}

struct Account: Decodable {
    let starting_balance: Double?
    let current_balance: Double?
    let daily_realized_pnl: Double?
    let total_realized_pnl: Double?
    let trades_today: Int?
    let kill_switch: KillSwitch?
    let win_rate_10d: TenDay?
}

struct TenDay: Decodable {
    let total_trades: Int?
    let wins: Int?
    let losses: Int?
    let win_rate_pct: Int?
}

struct KillSwitch: Decodable {
    let daily_tripped: Bool?
    let persistent_tripped: Bool?
}

// MARK: - Helpers

/// "MSFT261012C00537500" -> "MSFT 537.5C"
func occLabel(_ occ: String) -> String {
    let s = occ.trimmingCharacters(in: .whitespaces)
    guard s.count > 15 else { return s }
    let tail = s.suffix(15)                     // yymmdd + C/P + 8-digit strike
    let root = s.dropLast(15)
    let cp = tail.dropFirst(6).prefix(1)
    guard let raw = Double(tail.suffix(8)) else { return s }
    let strike = raw / 1000
    let k = strike == strike.rounded() ? String(Int(strike)) : String(strike)
    return "\(root) \(k)\(cp)"
}

/// "2026-10-12T10:52:03-04:00" -> "10:52"
func hhmm(_ iso: String?) -> String {
    guard let iso, iso.count >= 16 else { return "" }
    let i = iso.index(iso.startIndex, offsetBy: 11)
    return String(iso[i..<iso.index(i, offsetBy: 5)])
}

func etToday() -> String {
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: "America/New_York")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    enum Tab: String, CaseIterable { case alerts = "Alerts", chart = "Chart", watch = "Watchlist", swing = "Swing", trade = "Trading", settings = "Settings" }

    @Published var tab: Tab = .alerts
    @Published var chartIndex = 0

    @Published var alerts: MobileAlerts?
    @Published var watch: [WatchItem] = []
    @Published var gex: Gex?
    @Published var swing: SwingResp?
    @Published var positions: [Position] = []
    @Published var closedToday: [ClosedTrade] = []
    @Published var account: Account?
    @Published var offline = false

    static let chartTickers = ["SPX", "SPY", "QQQ", "NVDA", "AAPL", "MSFT", "GOOGL", "AMZN", "META", "TSLA"]

    func refresh(server: String) async {
        guard let api = API(server) else { offline = true; return }
        async let a: MobileAlerts? = try? await api.get("api/mobile/alerts")
        async let w: WatchResp? = try? await api.get("api/watchlist")
        async let c: ContextResp? = try? await api.get("api/context")
        async let sw: SwingResp? = try? await api.get("api/swing")
        async let p: PositionsResp? = try? await api.get("api/positions")
        async let pf: PerformanceResp? = try? await api.get("api/performance")
        async let ac: Account? = try? await api.get("api/account")

        let (ra, rw, rc, rsw, rp, rpf, rac) = await (a, w, c, sw, p, pf, ac)
        offline = ra == nil && rw == nil && rsw == nil
        if let ra { alerts = ra }
        if let rw { watch = rw.items ?? [] }
        if let rc { gex = rc.gex }
        if let rsw { swing = rsw }
        if let rp { positions = rp.positions ?? [] }
        if let rpf {
            let today = etToday()
            closedToday = (rpf.trades ?? []).filter { ($0.closed_at_et ?? "").hasPrefix(today) }
        }
        if let rac { account = rac }
    }

    /// Plain-English answer for Settings › Test Connection.
    static func diagnose(server: String) async -> String {
        guard let api = API(server) else { return "Enter the Icarus address first." }
        let host = api.base.host ?? server
        do {
            let _: Health = try await api.get("api/health")
        } catch {
            return "Can't reach \(host): \(error.localizedDescription). Check that the Icarus API is running on the PC and that `tailscale serve --bg 8765` was run there."
        }
        do {
            let _: MobileAlerts = try await api.get("api/mobile/alerts")
        } catch {
            return "Reached Icarus, but the alert feed failed (\(error.localizedDescription)). Start the API with `python mobile_api.py`, not run_local.py."
        }
        return "Connected to Icarus at \(host)."
    }

    func openChart(_ symbol: String) {
        if let i = Store.chartTickers.firstIndex(of: symbol) {
            chartIndex = i
            tab = .chart
        }
    }
}
