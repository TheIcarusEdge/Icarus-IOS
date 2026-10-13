import SwiftUI

// MARK: - Watchlist

struct WatchlistView: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store

    var body: some View {
        Screen {
            group("Mag 7", store.watch.filter { $0.bucket == "mag7" })
            group("Icarus Picks", store.watch.filter { $0.bucket != "mag7" })
        }
    }

    @ViewBuilder private func group(_ title: String, _ rows: [WatchItem]) -> some View {
        if !rows.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(s.f(22, .bold))
                Spacer()
                Text("vs SPY").font(s.f(13)).foregroundStyle(s.p.dim)
            }
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 4)
            ForEach(rows) { w in
                Button { store.openChart(w.symbol) } label: { row(w) }
                    .buttonStyle(.plain)
                Hairline().padding(.horizontal, 20)
            }
        }
    }

    private func row(_ w: WatchItem) -> some View {
        let up = (w.change_pct ?? 0) >= 0
        let relUp = (w.rel_to_spy_pct ?? 0) >= 0
        let vol = w.vol_ratio.map { String(format: " · Vol %.1fx", $0) } ?? ""
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(w.symbol).font(s.f(17, .semibold))
                Text(pct(w.rel_to_spy_pct, digits: 2) + vol)
                    .font(s.f(14)).lineLimit(1)
                    .foregroundStyle(relUp ? s.p.green : s.p.red)
            }
            Spacer()
            ResultBox(label: money(w.price), fill: up ? s.p.green : s.p.red, minWidth: 104)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Swing

struct SwingView: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store

    var body: some View {
        Screen {
            let roll = store.swing?.rollup
            VStack(alignment: .leading, spacing: 4) {
                Text("SWING · ERA A").font(s.f(13, .semibold)).tracking(1).foregroundStyle(s.p.dim)
                Text(rate(roll?.posted)).font(s.f(40, .bold))
                Text(roll?.posted.map { "\($0.wins) / \($0.n) posted · +50% before expiry" } ?? "No resolved signals")
                    .font(s.f(15)).foregroundStyle(s.p.dim)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

            HStack(spacing: 0) {
                LabeledValue(label: "Posted", value: rate(roll?.posted))
                LabeledValue(label: "Gated (Shadow)", value: rate(roll?.shadow))
                LabeledValue(label: "Tracking", value: "\(store.swing?.tracking?.count ?? 0)")
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
            Hairline()

            splits("By Direction", roll?.direction)
            splits("By Method", roll?.method)
            splits("By Regime", roll?.regime)

            let tracking = store.swing?.tracking ?? []
            if !tracking.isEmpty {
                SectionLabel(text: "Tracking")
                ForEach(tracking) { r in
                    cell(r)
                    Hairline().padding(.horizontal, 20)
                }
            }

            let recent = Array((store.swing?.resolved ?? []).suffix(12).reversed())
            if !recent.isEmpty {
                SectionLabel(text: "Recent Results")
                ForEach(recent) { r in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(r.ticker) \(r.strike.map { String(format: "%g", $0) } ?? "")\(r.cp ?? "")")
                                .font(s.f(17, .semibold))
                            Text("\(shortDate(r.date)) · \(titleCase(r.method))")
                                .font(s.f(14)).foregroundStyle(s.p.dim).lineLimit(1)
                        }
                        Spacer()
                        LabeledValue(label: "Peak", value: pct(r.peak_pct),
                                     color: (r.peak_pct ?? 0) >= 0 ? s.p.green : s.p.red)
                            .frame(width: 72)
                        ResultBox(label: r.hit50 == 1 ? "HIT" : "MISS",
                                  fill: r.hit50 == 1 ? s.p.green : s.p.red, minWidth: 64)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    Hairline().padding(.horizontal, 20)
                }
            }
        }
    }

    private func rate(_ c: WinCount?) -> String {
        guard let c, c.n > 0 else { return "—" }
        return "\(Int((Double(c.wins) / Double(c.n) * 100).rounded()))%"
    }

    private func shortDate(_ d: String?) -> String {
        guard let d, d.count >= 10 else { return d ?? "" }
        return String(d.dropFirst(5).prefix(5)).replacingOccurrences(of: "-", with: "/")
    }

    @ViewBuilder private func splits(_ title: String, _ rows: [Split]?) -> some View {
        if let rows, !rows.isEmpty {
            SectionLabel(text: title)
            ForEach(rows.indices, id: \.self) { i in
                let r = rows[i]
                let rate = r.n > 0 ? Double(r.w) / Double(r.n) : 0
                VStack(spacing: 8) {
                    HStack {
                        Text(titleCase(r.k)).font(s.f(16, .semibold))
                        Spacer()
                        Text("\(r.w) / \(r.n)").font(s.f(14)).foregroundStyle(s.p.dim)
                        Text("\(Int((rate * 100).rounded()))%").font(s.f(16, .semibold))
                            .frame(width: 52, alignment: .trailing)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(s.p.line)
                            Rectangle().fill(rate >= 0.5 ? s.p.green : s.p.red)
                                .frame(width: g.size.width * max(rate, 0.02))
                        }
                    }
                    .frame(height: 2)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
    }

    private func cell(_ r: SwingRow) -> some View {
        let call = (r.cp ?? "").uppercased() == "C" || (r.direction ?? "").lowercased().hasPrefix("bull")
        let tint = call ? s.p.green : s.p.red
        let progress = min(max((r.peak_pct ?? 0) / 50, 0.03), 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(r.ticker) \(r.strike.map { String(format: "%g", $0) } ?? "")\(r.cp ?? "")")
                        .font(s.f(17, .semibold))
                    Text("\(titleCase(r.method)) · exp \(shortDate(r.expiry))")
                        .font(s.f(14)).foregroundStyle(s.p.dim).lineLimit(1)
                }
                Spacer()
                Text(call ? "CALL" : "PUT")
                    .font(s.f(14, .bold)).foregroundStyle(tint)
                    .frame(minWidth: 72, minHeight: 32)
                    .overlay(Rectangle().stroke(tint, lineWidth: 1))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(s.p.line)
                    Rectangle().fill(s.p.acc).frame(width: g.size.width * progress)
                }
            }
            .frame(height: 2)
            HStack {
                Text("Entry " + money(r.entry_mid)); Spacer()
                Text("Peak " + pct(r.peak_pct)); Spacer()
                Text("Low " + pct(r.min_pct))
            }
            .font(s.f(13)).foregroundStyle(s.p.dim)
            HStack {
                Text("Inv " + money(r.invalid)); Spacer()
                Text("Spot " + money(r.spot)); Spacer()
                Text("Tgt " + money(r.target))
            }
            .font(s.f(13)).foregroundStyle(s.p.dim)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

// MARK: - Trading (sandbox)

struct TradingView: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store

    var body: some View {
        Screen {
            let a = store.account
            let ks = a?.kill_switch
            let status = (ks?.persistent_tripped ?? false) ? ("Halted", s.p.red)
                       : (ks?.daily_tripped ?? false) ? ("Paused", s.p.red) : ("Active", s.p.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("SANDBOX BALANCE").font(s.f(13, .semibold)).tracking(1).foregroundStyle(s.p.dim)
                Text(money(a?.current_balance)).font(s.f(40, .bold))
                HStack(spacing: 6) {
                    Text("Today " + signedMoney(a?.daily_realized_pnl))
                        .foregroundStyle(tint(a?.daily_realized_pnl))
                    Text("·").foregroundStyle(s.p.dim)
                    Text("All-Time " + signedMoney(a?.total_realized_pnl))
                        .foregroundStyle(tint(a?.total_realized_pnl))
                }
                .font(s.f(15))
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

            let ten = a?.win_rate_10d
            HStack(spacing: 0) {
                LabeledValue(label: "Status", value: status.0, color: status.1)
                LabeledValue(label: "10-Day Win", value: (ten?.total_trades ?? 0) > 0 ? "\(ten?.win_rate_pct ?? 0)%" : "—")
                LabeledValue(label: "10-Day W / L", value: "\(ten?.wins ?? 0) / \(ten?.losses ?? 0)")
                LabeledValue(label: "Today", value: "\(a?.trades_today ?? 0)")
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
            Hairline()

            if !store.positions.isEmpty {
                SectionLabel(text: "Open")
                ForEach(store.positions) { p in
                    cell(occLabel(p.symbol), hhmm(p.opened_at_et), p.entry_premium, "Now", p.live_mark,
                         p.unrealized_pnl, p.unrealized_pct)
                    Hairline().padding(.horizontal, 20)
                }
            }
            if !store.closedToday.isEmpty {
                SectionLabel(text: "Closed Today")
                ForEach(store.closedToday) { t in
                    cell(occLabel(t.symbol), hhmm(t.closed_at_et), t.entry_premium, "Exit", t.exit_premium,
                         t.pnl_usd, t.pnl_pct)
                    Hairline().padding(.horizontal, 20)
                }
            }
            if store.positions.isEmpty && store.closedToday.isEmpty {
                Text("No sandbox trades today.")
                    .font(s.f(15)).foregroundStyle(s.p.dim)
                    .padding(.horizontal, 20).padding(.top, 24)
            }
        }
    }

    private func tint(_ v: Double?) -> Color { (v ?? 0) >= 0 ? s.p.green : s.p.red }

    private func signedMoney(_ v: Double?) -> String {
        guard let v else { return "—" }
        return (v >= 0 ? "+" : "−") + String(format: "$%.2f", abs(v))
    }

    private func cell(_ contract: String, _ time: String, _ entry: Double?, _ nowLabel: String,
                      _ now: Double?, _ pnl: Double?, _ change: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(contract).font(s.f(18, .bold))
                Spacer()
                Text(time).font(s.f(14)).foregroundStyle(s.p.dim)
            }
            HStack(alignment: .bottom, spacing: 0) {
                LabeledValue(label: "Entry", value: money(entry))
                LabeledValue(label: nowLabel, value: money(now))
                LabeledValue(label: "P&L", value: signedMoney(pnl), color: pnl == nil ? nil : tint(pnl))
                ResultBox(label: pct(change), fill: change == nil ? nil : tint(change), minWidth: 72)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.style) private var s
    @AppStorage("theme") private var theme = ThemeID.dark.rawValue
    @AppStorage("font") private var font = FontID.grotesk.rawValue
    @AppStorage("server") private var server = ""
    @State private var draft = ""
    @State private var testing = false
    @State private var testResult: String?
    let lock: () -> Void

    var body: some View {
        Screen {
            SectionLabel(text: "Theme")
            ForEach(ThemeID.allCases) { t in
                option(t.title, selected: theme == t.rawValue, font: s.f(17, .semibold),
                       swatches: [t.palette.bg, t.palette.acc, t.palette.green, t.palette.red]) { theme = t.rawValue }
            }

            SectionLabel(text: "Font")
            ForEach(FontID.allCases) { f in
                option(f.title, selected: font == f.rawValue, font: Style.font(f, 17, .semibold), swatches: []) { font = f.rawValue }
            }

            SectionLabel(text: "Icarus Address")
            HStack(spacing: 12) {
                TextField("https://pc-name.tailnet.ts.net", text: $draft)
                    .font(s.f(15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit { server = draft }
                Button("Save") { server = draft }
                    .font(s.f(15, .semibold))
                    .foregroundStyle(draft == server ? s.p.off : s.p.text)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 20)
            Hairline().padding(.horizontal, 20)
            action(testing ? "Testing…" : "Test Connection") {
                guard !testing else { return }
                if !draft.isEmpty { server = draft }
                testing = true
                Task {
                    testResult = await Store.diagnose(server: server)
                    testing = false
                }
            }
            if let testResult {
                Text(testResult)
                    .font(s.f(14))
                    .foregroundStyle(testResult.hasPrefix("Connected") ? s.p.green : s.p.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.vertical, 12)
            }

            SectionLabel(text: "Security")
            action("Lock Now") { lock() }
            action("Change Passcode") { Passcode.clear(); lock() }
        }
        .onAppear { draft = server }
    }

    private func option(_ title: String, selected: Bool, font: Font, swatches: [Color],
                        _ pick: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: pick) {
                HStack(spacing: 4) {
                    Text(title).font(font).foregroundStyle(s.p.text)
                    Spacer()
                    ForEach(swatches.indices, id: \.self) { i in
                        Rectangle().fill(swatches[i])
                            .overlay(Rectangle().stroke(s.p.line, lineWidth: 1))
                            .frame(width: 14, height: 14)
                    }
                    Rectangle()
                        .fill(selected ? s.p.text : .clear)
                        .overlay(Rectangle().stroke(selected ? s.p.text : s.p.off, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                        .padding(.leading, 8)
                }
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            Hairline()
        }
        .padding(.horizontal, 20)
    }

    private func action(_ title: String, _ run: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: run) {
                Text(title).font(s.f(17, .semibold)).foregroundStyle(s.p.text)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Hairline()
        }
        .padding(.horizontal, 20)
    }
}
