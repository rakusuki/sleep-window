import AlarmKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var slices: [SleepSlice] = []
    @Published var source = ""
    @Published var alarms: [Alarm] = []
    @Published var message = "ヘルスケアを接続して、Apple Watchの記録を読み込みます。"
    @Published var error: String?
    @Published var busy = false
    @Published var loadedAt: Date?
    let health = HealthReader()
    let alarmService = AlarmService()
    var sources: [String] { Array(Set(slices.map(\.source))).sorted() }
    var selected: [SleepSlice] { slices.filter { $0.source == source } }

    func connect() async {
        busy = true
        defer { busy = false }
        do {
            try await health.authorize()
            slices = try await health.read()
            if !sources.contains(source) { source = sources.first ?? "" }
            loadedAt = Date()
            message = slices.isEmpty ? "記録がありません。読み取り未許可・未同期・未記録の可能性があります。" : "記録を読み込みました。Apple Watchの記録元を選んでください。"
        } catch { self.error = error.localizedDescription }
    }

    func syncAlarms() {
        do { alarms = try alarmService.current() }
        catch { self.error = error.localizedDescription }
    }

    func reserve(_ date: Date) async {
        busy = true
        defer { busy = false }
        do {
            try await alarmService.schedule(at: date)
            syncAlarms()
            message = "アラームを予約しました。今回は1回だけ鳴ります。"
        } catch { self.error = error.localizedDescription; syncAlarms() }
    }

    func cancel(_ id: UUID) {
        do { try alarmService.cancel(id); syncAlarms() }
        catch { self.error = error.localizedDescription }
    }
}
