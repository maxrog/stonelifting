//
//  ProfileView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 12/3/25.
//

import SwiftUI

// MARK: - Profile View

/// Displays user profile with stats and achievements
struct ProfileView: View {
    // MARK: - Properties

    private let authService = AuthService.shared
    private let stoneService = StoneService.shared
    private let logger = AppLogger()

    @State private var stats: StoneStats?
    #if DEBUG
    @State private var showDebugSettings = false
    #endif

    private var username: String {
        authService.currentUser?.username ?? "User"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileHeaderSection
                    statsSection
                    achievementsSection

                    Spacer()

                    logoutButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDebugSettings = true
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                }
                #endif
            }
            .onAppear {
                loadStats()
            }
            .refreshable {
                await refreshStats()
            }
            #if DEBUG
            .sheet(isPresented: $showDebugSettings) {
                DebugSettingsView()
            }
            #endif
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(username.prefix(1).uppercased())
                        .font(.system(size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            Text(username)
                .font(.title2)
                .fontWeight(.bold)

            if let email = authService.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let stats = stats {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Stones",
                            value: "\(stats.totalStones)",
                            icon: "figure.strengthtraining.traditional",
                            color: .blue
                        )

                        StatCard(
                            title: "Heaviest",
                            value: String(format: "%.0f lbs", stats.heaviestStone),
                            icon: "scalemass.fill",
                            color: .orange
                        )
                    }

                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Weight",
                            value: String(format: "%.0f lbs", stats.totalWeight),
                            icon: "sum",
                            color: .green
                        )

                        StatCard(
                            title: "Average",
                            value: String(format: "%.0f lbs", stats.averageWeight),
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                    }

                    HStack(spacing: 12) {
                        StatCard(
                            title: "Public",
                            value: "\(stats.publicStones)",
                            icon: "globe",
                            color: .cyan
                        )

                        StatCard(
                            title: "With Location",
                            value: "\(stats.stonesWithLocation)",
                            icon: "location.fill",
                            color: .red
                        )
                    }
                }
            } else {
                Text("No stats available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var achievementsSection: some View {
        VStack(spacing: 16) {
            Text("Achievements")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let stats = stats, stats.totalStones > 0 {
                let earnedAchievements = getEarnedAchievements(from: stats.stones)

                if earnedAchievements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        Text("No achievements yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Lift a stone to chest level to earn your first achievement!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(AchievementTier.allCases.filter { $0 != .none }, id: \.self) { tier in
                            let isEarned = earnedAchievements.contains(tier)
                            AchievementBadgeRow(
                                tier: tier,
                                isEarned: isEarned
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("Add stones to unlock achievements")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var logoutButton: some View {
        Button("Logout") {
            authService.logout()
        }
        .buttonStyle(.bordered)
        .foregroundColor(.red)
        .padding(.top, 20)
    }

    private func loadStats() {
        stats = stoneService.userStats
    }

    private func refreshStats() async {
        await stoneService.fetchUserStones(shouldCache: true)
        stats = stoneService.userStats
    }

    private func getEarnedAchievements(from stones: [Stone]) -> Set<AchievementTier> {
        var earned = Set<AchievementTier>()

        for stone in stones {
            let tier = stone.achievementTier
            if tier != .none {
                earned.insert(tier)
            }
        }

        return earned
    }

    private func colorForAchievement(_ tier: AchievementTier) -> Color {
        switch tier.color {
        case "bronze": return .orange
        case "silver": return .gray
        case "gold": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Achievement Badge Row

struct AchievementBadgeRow: View {
    let tier: AchievementTier
    let isEarned: Bool

    private func colorForAchievement(_ tier: AchievementTier) -> Color {
        switch tier.color {
        case "bronze": return .orange
        case "silver": return .gray
        case "gold": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isEarned ? colorForAchievement(tier).opacity(0.2) : Color(.systemGray6))
                    .frame(width: 56, height: 56)

                Image(systemName: tier.icon)
                    .font(.title2)
                    .foregroundColor(isEarned ? colorForAchievement(tier) : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tier.displayName)
                    .font(.headline)
                    .foregroundColor(isEarned ? .primary : .secondary)

                Text("\(Int(tier.weightRequirementLbs)) lbs (\(Int(tier.weightRequirementKg)) kg) to chest")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isEarned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(isEarned ? colorForAchievement(tier).opacity(0.05) : Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .opacity(isEarned ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
}
