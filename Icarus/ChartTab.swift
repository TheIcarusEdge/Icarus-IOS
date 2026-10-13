import Charts
import SwiftUI

struct ChartTab: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store
    @AppStorage("server") private var server = ""

    @State private var today: [Bar] = []
    @State private var priorClose: Double?
    @State private var loadedFor = ""

    private var tickers: [String] { Store.chartTickers }
    private var tk: String { tickers[store.chartIndex] }

    private struct Level: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    var body: some View {
        Screen {
            VStack(alignment: .leading, spacing: 0) {
                header
                priceChart.frame(height: 240).padding(.top, 8)
                volumeChart.frame(height: 48)
                HStack {
                    Text("09:30"); Spacer(); Text("12:00"); Spacer(); Text("16:00")
                }
                .font(s.f(12)).foregroundStyle(s.p.dim)
                .padding(.horizontal, 20).padding(.top, 6)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 30).onEnded { v in
                    let dx = v.translation.width
                    guard abs(dx) > 40, abs(dx) > abs(v.translation.height) else { return }
                    let n = tickers.count
                    store.chartIndex = (store.chartIndex + (dx < 0 ? 1 : -1) + n) % n
                }
            )

            SectionLabel(text: "Levels")
            ForEach(levels) { l in
                HStack {
                    Text(l.id).foregroundStyle(l.color).frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.2f", l.value)).frame(maxWidth: .infinity, alignment: .trailing)
                    Text(dist(l.value)).foregroundStyle(s.p.dim).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(s.f(15))
                .padding(.vertical, 12).padding(.horizontal, 20)
                Hairline().padding(.horizontal, 20)
            }
        }
        .task(id: "\(tk)|\(server)") { await load() }
    }

    // MARK: pieces

    private var last: Double? { today.last?.c }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tk).font(s.f(28, .bold))
                Text(changeLine).font(s.f(15)).foregroundStyle(changeColor)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(tickers.indices, id: \.self) { i in
                    Rectangle().fill(i == store.chartIndex ? s.p.text : s.p.off).frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 6)
            .accessibilityLabel("Swipe the chart to change ticker")
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private var change: Double? {
        guard let last, let priorClose, priorClose > 0 else { return nil }
        return (last / priorClose - 1) * 100
    }
    private var changeLine: String { last.map { String(format: "$%.2f", $0) + " · " + pct(change, digits: 2) } ?? "—" }
    private var changeColor: Color { (change ?? 0) >= 0 ? s.p.green : s.p.red }

    private struct VP: Identifiable { let id: Date; let value: Double }

    private var vwap: [VP] {
        var pv = 0.0, vol = 0.0
        return today.map { b in
            let v = max(b.v ?? 0, 1)
            pv += (b.h + b.l + b.c) / 3 * v
            vol += v
            return VP(id: b.date, value: pv / vol)
        }
    }

    private var levels: [Level] {
        var out: [Level] = []
        if tk == "SPY", let g = store.gex {
            if let v = g.call_wall { out.append(Level(id: "Call Wall", value: v, color: s.p.green)) }
            if let v = g.king_node { out.append(Level(id: "King Node", value: v, color: s.p.king)) }
            if let v = g.gamma_flip { out.append(Level(id: "Gamma Flip", value: v, color: s.p.dim)) }
            if let v = g.put_wall { out.append(Level(id: "Put Wall", value: v, color: s.p.red)) }
        }
        if let v = vwap.last?.value { out.append(Level(id: "VWAP", value: v, color: s.p.vwap)) }
        if let v = priorClose { out.append(Level(id: "Prior Close", value: v, color: s.p.dim)) }
        return out
    }

    private var domain: ClosedRange<Double> {
        let lows = today.map(\.l), highs = today.map(\.h)
        guard let lo = lows.min(), let hi = highs.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.15, hi * 0.0005)
        var a = lo - pad, b = hi + pad
        for l in levels where abs(l.value - (last ?? l.value)) / l.value < 0.012 {
            a = min(a, l.value - pad / 2); b = max(b, l.value + pad / 2)
        }
        return a...b
    }

    private var markers: [(Date, Double, Bool)] {
        let rows = (store.alerts?.alerts ?? []).filter { $0.ticker == tk }
        return rows.compactMap { a in
            guard let b = today.first(where: { hhmm(isoET($0.date)) >= a.time }) else { return nil }
            return (b.date, b.c, a.cp == "C")
        }
    }

    private var priceChart: some View {
        let dom = domain
        return Chart {
            ForEach(levels.filter { $0.id != "VWAP" && dom.contains($0.value) }) { l in
                RuleMark(y: .value(l.id, l.value))
                    .foregroundStyle(l.color)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: l.id == "Gamma Flip" ? [2, 4] : [4, 4]))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f", l.value)).font(s.f(11)).foregroundStyle(l.color)
                    }
            }
            ForEach(vwap) { p in
                LineMark(x: .value("t", p.id), y: .value("vwap", p.value), series: .value("s", "vwap"))
                    .foregroundStyle(s.p.vwap)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
            ForEach(today, id: \.t) { b in
                LineMark(x: .value("t", b.date), y: .value("px", b.c), series: .value("s", "px"))
                    .foregroundStyle(s.p.acc)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            ForEach(Array(markers.enumerated()), id: \.offset) { _, m in
                PointMark(x: .value("t", m.0), y: .value("a", m.1))
                    .symbol(.triangle)
                    .symbolSize(60)
                    .foregroundStyle(m.2 ? s.p.green : s.p.red)
            }
        }
        .chartYScale(domain: dom)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .padding(.horizontal, 16)
    }

    private var volumeChart: some View {
        Chart(today, id: \.t) { b in
            BarMark(x: .value("t", b.date), y: .value("v", b.v ?? 0))
                .foregroundStyle(s.p.acc.opacity(0.35))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(.horizontal, 16)
    }

    private func dist(_ v: Double) -> String {
        guard let last, last > 0 else { return "—" }
        return pct((v - last) / last * 100, digits: 2)
    }

    // MARK: data

    private func load() async {
        guard let api = API(server) else { return }
        let key = tk
        guard let r: BarsResp = try? await api.get("api/bars", ["ticker": key, "days": "2"]),
              let bars = r.bars, !bars.isEmpty, key == tk else { return }
        let lastDay = etDay(bars.last!.date)
        let todays = bars.filter { etDay($0.date) == lastDay && isRegular($0.date) }
        let prior = bars.filter { etDay($0.date) < lastDay && isRegular($0.date) }
        today = todays
        priorClose = prior.last?.c
        loadedFor = key
    }
}

private let etCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

private func etDay(_ d: Date) -> String {
    let p = etCal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
}

private func isRegular(_ d: Date) -> Bool {
    let p = etCal.dateComponents([.hour, .minute], from: d)
    let m = (p.hour ?? 0) * 60 + (p.minute ?? 0)
    return m >= 570 && m < 960
}

/// ET wall-clock ISO-ish string for a bar, so it compares with "HH:MM" alert times.
private func isoET(_ d: Date) -> String {
    let p = etCal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    return String(format: "%04d-%02d-%02dT%02d:%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0, p.hour ?? 0, p.minute ?? 0)
}
