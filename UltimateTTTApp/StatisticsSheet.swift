import SwiftUI
import UltimateTTTCore

struct StatisticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var statistics: GameStatisticsStore
    let showLeaderboards: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Your record")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(GameStyle.text)
                    Text("Finished games are saved on this device. Online wins can also appear on Game Center.")
                        .font(.subheadline)
                        .foregroundStyle(GameStyle.muted)

                    summaryCard(
                        title: "ONLINE MATCHES", mode: .online,
                        summary: statistics.history.summary(for: .online)
                    )

                    Button(action: showLeaderboards) {
                        Label("Game Center leaderboard", systemImage: "trophy")
                            .font(.headline)
                            .foregroundStyle(GameStyle.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(GameStyle.x, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)

                    summaryCard(
                        title: "VS COMPUTER", mode: .solo,
                        summary: statistics.history.summary(for: .solo)
                    )

                    VStack(spacing: 0) {
                        ForEach(Difficulty.allCases) { difficulty in
                            difficultyRow(difficulty)
                            if difficulty != Difficulty.allCases.last {
                                Divider().overlay(GameStyle.outline)
                                    .padding(.horizontal, 15)
                            }
                        }
                    }
                    .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 16))

                    if !statistics.history.matches.isEmpty {
                        VStack(alignment: .leading, spacing: 11) {
                            Text("RECENT RESULTS")
                                .font(.caption.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(GameStyle.muted)
                            ForEach(statistics.history.matches.suffix(6).reversed()) { match in
                                HStack {
                                    Image(systemName: match.outcome == .win ? "checkmark.circle.fill" :
                                            match.outcome == .draw ? "minus.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(match.outcome == .win ? GameStyle.x :
                                            match.outcome == .draw ? GameStyle.muted : GameStyle.o)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(match.outcome.rawValue.capitalized)
                                            .font(.subheadline.weight(.semibold))
                                        Text(match.mode == .online ? "Online" : "Computer · \(match.difficulty?.label ?? "—")")
                                            .font(.caption)
                                            .foregroundStyle(GameStyle.muted)
                                    }
                                    Spacer()
                                    Text("\(match.moves) moves")
                                        .font(.caption)
                                        .foregroundStyle(GameStyle.muted)
                                }
                            }
                        }
                        .padding(16)
                        .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func summaryCard(
        title: String, mode: PlayedMode, summary: MatchSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(GameStyle.muted)
            HStack {
                metric("Games", value: "\(summary.total)")
                metric("Won", value: "\(summary.wins)")
                metric("Win rate", value: "\(summary.winPercentage)%")
            }
            HStack(spacing: 16) {
                Label("\(statistics.history.winStreak(for: mode)) current streak", systemImage: "flame")
                Label("\(statistics.history.bestWinStreak(for: mode)) best", systemImage: "star")
            }
            .font(.caption)
            .foregroundStyle(GameStyle.muted)
            Text("\(summary.losses) losses · \(summary.draws) draws")
                .font(.caption)
                .foregroundStyle(GameStyle.muted)
        }
        .padding(16)
        .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(GameStyle.text)
            Text(title)
                .font(.caption)
                .foregroundStyle(GameStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func difficultyRow(_ difficulty: Difficulty) -> some View {
        let summary = statistics.history.summary(for: .solo, difficulty: difficulty)
        return HStack {
            Text(difficulty.label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(summary.wins)W · \(summary.losses)L · \(summary.draws)D")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(GameStyle.muted)
        }
        .foregroundStyle(GameStyle.text)
        .padding(16)
    }
}
