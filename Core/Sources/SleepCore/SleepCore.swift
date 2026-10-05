import Foundation

public enum SleepStage: Int, Codable, CaseIterable, Sendable {
    case awake, core, deep, rem, unspecified
    public var label: String {
        switch self {
        case .awake: return "覚醒"
        case .core: return "コア"
        case .deep: return "深い睡眠"
        case .rem: return "REM"
        case .unspecified: return "睡眠・段階不明"
        }
    }
}

public struct SleepSlice: Identifiable, Sendable {
    public let id: UUID
    public let start: Date
    public let end: Date
    public let stage: SleepStage
    public let source: String
    public init(id: UUID = UUID(), start: Date, end: Date, stage: SleepStage, source: String) {
        self.id = id; self.start = start; self.end = end; self.stage = stage; self.source = source
    }
}

public struct WakeChoice: Sendable {
    public let date: Date
    public let evidenceDays: Int
    public let reason: String
}

public enum WakePlanner {
    public static let historyDays = 14
    public static let minimumDays = 3
    public static let stepMinutes = 5

    public static func nextWake(hour: Int, minute: Int, now: Date, calendar: Calendar = .current) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute), matchingPolicy: .nextTime, repeatedTimePolicy: .first)
    }

    // 同じ時計時刻の過去データを比較する試験的なヒューリスティック。
    // 今夜の睡眠段階・睡眠周期・起床の快適さを測定するものではない。
    public static func choose(deadline: Date, windowMinutes: Int, now: Date, slices: [SleepSlice], calendar: Calendar = .current) -> WakeChoice {
        let fallback = WakeChoice(date: deadline, evidenceDays: 0, reason: "十分な履歴がないため指定時刻を使用")
        guard [10, 20, 30, 45, 60].contains(windowMinutes), deadline > now else { return fallback }
        // 入力に複数の記録元が混ざった場合は予測を行わない。
        guard Set(slices.map(\.source)).count == 1 else { return fallback }
        var bestDate = deadline
        var bestScore = 0.0
        var bestDays = 0
        // 遅い候補から評価し、同点なら睡眠時間を短くしない。
        for offset in stride(from: 0, through: windowMinutes, by: stepMinutes) {
            let candidate = deadline.addingTimeInterval(-Double(offset * 60))
            guard candidate > now.addingTimeInterval(60) else { continue }
            var observed = 0
            var core = 0
            for day in 1...historyDays {
                guard let historical = calendar.date(byAdding: .day, value: -day, to: candidate), historical < now else { continue }
                let states = Set(slices.filter { $0.start <= historical && historical < $0.end }.map(\.stage))
                // 重複は集合化し、矛盾した段階・段階不明は欠測として扱う。
                guard states.count == 1, let stage = states.first, stage != .unspecified else { continue }
                observed += 1
                if stage == .core { core += 1 }
            }
            guard observed >= minimumDays else { continue }
            let score = Double(core) / Double(observed)
            if score >= 0.6 && score > bestScore {
                bestScore = score; bestDate = candidate; bestDays = observed
            }
        }
        guard bestDays > 0 else { return fallback }
        return WakeChoice(date: bestDate, evidenceDays: bestDays, reason: "過去\(bestDays)日中、同時刻がコア睡眠の割合 \(Int(bestScore * 100))%。今夜の段階は未測定")
    }

    // 同じ時間帯の重複サンプルを合算しない。
    public static func sleepDuration(_ slices: [SleepSlice], from: Date, to: Date) -> TimeInterval {
        let ranges = slices.filter { $0.stage != .awake }.compactMap { slice -> (Date, Date)? in
            let a = max(from, slice.start), b = min(to, slice.end)
            return a < b ? (a, b) : nil
        }.sorted { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var active: (Date, Date)?
        for range in ranges {
            if let previous = active {
                if range.0 <= previous.1 { active = (previous.0, max(previous.1, range.1)) }
                else { total += previous.1.timeIntervalSince(previous.0); active = range }
            } else { active = range }
        }
        if let active { total += active.1.timeIntervalSince(active.0) }
        return total
    }
}
