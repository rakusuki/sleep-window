import Foundation
import HealthKit

@MainActor
final class HealthReader {
    private let store = HKHealthStore()
    private let type = HKCategoryType(.sleepAnalysis)

    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw AppIssue("この端末ではヘルスケアを利用できません。") }
        try await store.requestAuthorization(toShare: [], read: [type])
    }

    func read() async throws -> [SleepSlice] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -15, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result as? [HKCategorySample] ?? []) }
            }
            store.execute(query)
        }
        return samples.compactMap { sample in
            let stage: SleepStage
            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue: stage = .awake
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: stage = .core
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: stage = .deep
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: stage = .rem
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: stage = .unspecified
            default: return nil // inBedは睡眠時間に加えない。
            }
            let source = sample.sourceRevision.source
            let device = sample.device?.name ?? "端末不明"
            return SleepSlice(id: sample.uuid, start: sample.startDate, end: sample.endDate, stage: stage, source: "\(source.name) / \(device) [\(source.bundleIdentifier)]")
        }
    }
}

struct AppIssue: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
