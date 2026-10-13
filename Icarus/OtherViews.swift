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
            let posted = store.swing?.rollup?.posted
            VStack(alignment: .leading, spacing: 4) {
                Text("SWING · ERA A").font(s.f(13, .semibold)).tracking(1).foregroundStyle(s.p.dim)
                Text(posted.flatMap { $0.n > 0 ? "\(Int((Double($0.wins) / Double($0.n) * 100).rounded()))%" : nil } ?? "—")
                    .font(s.f(40, .bold))
                Text(posted.map { "\($0.wins) / \($0.n) posted" } ?? "No resolved signals")
                    .font(s.f(15)).foregroundStyle(s.p.dim)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
            Hairline()

            ForEach(store.swing?.tracking ?? []) { r in
                cell(r)
                Hairline().padding(.horizontal, 20)
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
                    Text(r.ticker).font(s.f(17, .semibold))
                    Text(titleCase(r.method)).font(s.f(14)).foregroundStyle(s.p.dim)
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
                Text("Inv " + money(r.invalid)); Spacer()
                Text("Peak " + pct(r.peak_pct)); Spacer()
                Text("Tgt " + money(r.target))
            }
            .font(s.f(13)).foregroundStyle(s.p.dim)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

// MARK: - Trading (sandbox) — percentages only, no balances

struct TradingView: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store

    var body: some View {
        Screen {
            let ks = store.account?.kill_switch
            let status = (ks?.persistent_tripped ?? false) ? ("Halted", s.p.red)
                       : (ks?.daily_tripped ?? false) ? ("Paused", s.p.red) : ("Active", s.p.green)
            let wins = store.closedToday.filter { ($0.pnl_pct ?? 0) > 0 }.count
            HStack(spacing: 0) {
                LabeledValue(label: "Status", value: status.0, color: status.1)
                LabeledValue(label: "Trades", value: "\(store.account?.trades_today ?? store.closedToday.count + store.positions.count)")
                LabeledValue(label: "Closed", value: "\(wins) / \(store.closedToday.count)",
                             color: wins > 0 ? s.p.green : nil)
            }
            .padding(.horizontal, 20).padding(.vertical, 20)
            Hairline()

            if !store.positions.isEmpty {
                SectionLabel(text: "Open")
                ForEach(store.positions) { p in
                    cell(occLabel(p.symbol), hhmm(p.opened_at_et), p.entry_premium, "Now", p.live_mark, p.unrealized_pct)
                    Hairline().padding(.horizontal, 20)
                }
            }
            if !store.closedToday.isEmpty {
                SectionLabel(text: "Closed Today")
                ForEach(store.closedToday) { t in
                    cell(occLabel(t.symbol), hhmm(t.closed_at_et), t.entry_premium, "Exit", t.exit_premium, t.pnl_pct)
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

    private func cell(_ contract: String, _ time: String, _ entry: Double?, _ nowLabel: String,
                      _ now: Double?, _ change: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(contract).font(s.f(18, .bold))
                Spacer()
                Text(time).font(s.f(14)).foregroundStyle(s.p.dim)
            }
            HStack(alignment: .bottom, spacing: 0) {
                LabeledValue(label: "Entry", value: money(entry))
                LabeledValue(label: nowLabel, value: money(now))
                ResultBox(label: pct(change), fill: change == nil ? nil : (change! >= 0 ? s.p.green : s.p.red))
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
