import SwiftUI

struct AlertsView: View {
    @Environment(\.style) private var s
    @EnvironmentObject private var store: Store
    @AppStorage("show_v4") private var showV4 = true
    @AppStorage("show_v5") private var showV5 = true
    @AppStorage("show_v6") private var showV6 = false

    private var visible: [AlertRow] {
        (store.alerts?.alerts ?? []).filter { on($0.origin) }
    }

    private func on(_ origin: String) -> Bool {
        switch origin {
        case "v4": return showV4
        case "v5": return showV5
        case "v6": return showV6
        default: return true
        }
    }

    var body: some View {
        Screen {
            HStack(alignment: .firstTextBaseline) {
                Text(dateTitle).font(s.f(28, .bold))
                Spacer()
                Text("\(visible.count) alerts").font(s.f(15)).foregroundStyle(s.p.dim)
            }
            .padding(.horizontal, 20).padding(.top, 20)

            HStack(spacing: 0) {
                rate("v4", $showV4)
                rate("v5", $showV5)
                rate("v6", $showV6)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            Hairline()

            ForEach(visible) { a in
                AlertCell(a: a)
                Hairline().padding(.horizontal, 20)
            }
        }
    }

    private var dateTitle: String {
        guard let d = store.alerts?.date else { return "Today" }
        let i = DateFormatter(); i.dateFormat = "yyyy-MM-dd"
        let o = DateFormatter(); o.dateFormat = "EEE MMM d"
        return i.date(from: d).map(o.string(from:)) ?? d
    }

    private func rate(_ key: String, _ isOn: Binding<Bool>) -> some View {
        let r = store.alerts?.rates?[key]
        let pctText = r.flatMap { $0.n > 0 ? "\(Int((Double($0.wins) / Double($0.n) * 100).rounded()))%" : nil } ?? "—"
        let color = isOn.wrappedValue ? s.p.text : s.p.off
        return Button { isOn.wrappedValue.toggle() } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.uppercased()).font(s.f(13, .semibold)).tracking(1)
                Text(pctText).font(s.f(26, .bold))
                Text(r.map { "\($0.wins) / \($0.n)" } ?? "— / —").font(s.f(13))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }
}

struct AlertCell: View {
    @Environment(\.style) private var s
    let a: AlertRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 6) {
                Text(a.contract).font(s.f(18, .bold)).lineLimit(1)
                Text(a.origin.uppercased())
                    .font(s.f(11, .semibold)).foregroundStyle(s.p.dim)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(Rectangle().stroke(s.p.line, lineWidth: 1))
                ForEach(a.tags, id: \.self) { t in Chip(label: label(t), fill: color(t)) }
                Spacer(minLength: 4)
                Text(a.time).font(s.f(14)).foregroundStyle(s.p.dim)
            }
            HStack(alignment: .bottom, spacing: 0) {
                LabeledValue(label: "Entry", value: money(a.entry))
                LabeledValue(label: "Target", value: money(a.target))
                LabeledValue(label: "Peak", value: pct(a.peak_pct),
                             color: (a.peak_pct ?? 0) >= 0 ? s.p.green : s.p.red)
                ResultBox(label: a.result == "win" ? "HIT" : a.result == "loss" ? "MISS" : "OPEN",
                          fill: a.result == "win" ? s.p.green : a.result == "loss" ? s.p.red : nil,
                          minWidth: 64)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private func label(_ t: String) -> String { t == "STOP" ? "Loss: Stop Loss Hit" : t }

    private func color(_ t: String) -> Color {
        switch t {
        case "TRIM": return s.p.green
        case "SUN": return s.p.sun
        default: return s.p.red
        }
    }
}
