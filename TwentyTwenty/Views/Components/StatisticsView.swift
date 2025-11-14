import SwiftUI

/// View displaying performance statistics from Vision model execution
struct StatisticsView: View {
    let statistics: PerformanceStatistics

    var body: some View {
        VStack(spacing: 12) {
            Text("Performance")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                StatisticCard(
                    icon: "clock.fill",
                    label: "Inference Time",
                    value: statistics.inferenceTimeString,
                    color: .blue
                )

                StatisticCard(
                    icon: "memorychip.fill",
                    label: "Memory Delta",
                    value: statistics.memoryDeltaString,
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Performance statistics")
    }
}

// MARK: - Statistic Card

/// Individual statistic card showing an icon, label, and value
struct StatisticCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    StatisticsView(
        statistics: PerformanceStatistics(
            from: {
                var tracker = PerformanceTracker()
                tracker.start()
                Thread.sleep(forTimeInterval: 0.1)
                tracker.stop()
                return tracker
            }()
        )
    )
    .padding()
}
