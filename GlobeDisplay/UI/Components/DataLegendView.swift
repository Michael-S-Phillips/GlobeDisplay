import SwiftUI

/// A popover that explains the color and symbol coding for active data overlays.
struct DataLegendView: View {

    let earthquakesEnabled: Bool
    let volcanoesEnabled:   Bool
    let wildfiresEnabled:   Bool
    let airQualityEnabled:  Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if earthquakesEnabled {
                section("Earthquakes") {
                    legendRow {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.1, blue: 0.1))
                            .frame(width: 14, height: 14)
                    } label: {
                        Text("< 1 hour ago")
                    }
                    legendRow {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.5, blue: 0.0))
                            .frame(width: 12, height: 12)
                    } label: {
                        Text("1 – 6 hours ago")
                    }
                    legendRow {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.9, blue: 0.0))
                            .frame(width: 10, height: 10)
                    } label: {
                        Text("Older")
                    }
                    Text("Circle size reflects magnitude.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    Text("Outer ring = shallow (<70 km). Faded = deep (>300 km).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if volcanoesEnabled {
                section("Volcanoes") {
                    legendRow {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.9, green: 0.0, blue: 0.8))
                    } label: {
                        Text("Active eruption (Smithsonian GVP)")
                    }
                }
            }

            if wildfiresEnabled {
                section("Wildfires") {
                    legendRow {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.4, blue: 0.0))
                            .frame(width: 12, height: 12)
                    } label: {
                        Text("Active wildfire (GDACS)")
                    }
                }
            }

            if airQualityEnabled {
                section("Air Quality (US AQI)") {
                    legendRow {
                        Circle().fill(Color(red: 0.0, green: 0.8, blue: 0.2)).frame(width: 12, height: 12)
                    } label: { Text("0–50 Good") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.9, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("51–100 Moderate") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.5, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("101–150 Sensitive groups") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.1, blue: 0.1)).frame(width: 12, height: 12)
                    } label: { Text("151–200 Unhealthy") }
                    legendRow {
                        Circle().fill(Color(red: 0.6, green: 0.0, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("201+ Very Unhealthy / Hazardous") }
                    Text("Source: Open-Meteo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .frame(minWidth: 240)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func legendRow<Symbol: View, Label: View>(
        @ViewBuilder symbol: () -> Symbol,
        @ViewBuilder label: () -> Label
    ) -> some View {
        HStack(spacing: 8) {
            symbol()
                .frame(width: 16, height: 16)
            label()
                .font(.caption)
        }
    }
}
