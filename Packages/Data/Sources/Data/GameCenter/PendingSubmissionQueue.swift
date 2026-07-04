import Foundation

/// Offline persistence for Game Center submissions: scores and achievement
/// progress that could not be delivered are retried after the next
/// successful authentication. UserDefaults-backed JSON; small by nature.
struct PendingSubmissionQueue {
    struct PendingScore: Codable, Equatable {
        let value: Int
        let leaderboardID: String
    }

    struct PendingAchievement: Codable, Equatable {
        let achievementID: String
        let percent: Double
    }

    private struct Payload: Codable {
        var scores: [PendingScore] = []
        var achievements: [PendingAchievement] = []
    }

    private static let key = "gamecenter.pendingSubmissions"
    /// Bounds the queue so a permanently-offline device can't grow it forever.
    private static let maxEntries = 200

    func enqueueScore(_ value: Int, leaderboardID: String) {
        var payload = load()
        payload.scores.append(PendingScore(value: value, leaderboardID: leaderboardID))
        if payload.scores.count > Self.maxEntries {
            payload.scores.removeFirst(payload.scores.count - Self.maxEntries)
        }
        save(payload)
    }

    func enqueueAchievement(id: String, percent: Double) {
        var payload = load()
        // Keep only the highest percent per achievement.
        if let index = payload.achievements.firstIndex(where: { $0.achievementID == id }) {
            if payload.achievements[index].percent < percent {
                payload.achievements[index] = PendingAchievement(
                    achievementID: id,
                    percent: percent,
                )
            }
        } else {
            payload.achievements.append(PendingAchievement(achievementID: id, percent: percent))
        }
        save(payload)
    }

    /// Removes and returns everything queued.
    func drain() -> (scores: [PendingScore], achievements: [PendingAchievement]) {
        let payload = load()
        save(Payload())
        return (payload.scores, payload.achievements)
    }

    var isEmpty: Bool {
        let payload = load()
        return payload.scores.isEmpty && payload.achievements.isEmpty
    }

    private func load() -> Payload {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return Payload() }
        return payload
    }

    private func save(_ payload: Payload) {
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
