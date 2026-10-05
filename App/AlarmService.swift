import AlarmKit
import SwiftUI

struct WakeMetadata: AlarmMetadata {}

@MainActor
final class AlarmService {
    private let manager = AlarmManager.shared

    func schedule(at date: Date) async throws {
        guard date.timeIntervalSinceNow > 5 else { throw AppIssue("予約時刻が近すぎます。設定し直してください。") }
        let authorization = try await manager.requestAuthorization()
        guard authorization == .authorized else { throw AppIssue("アラームの許可がありません。iPhoneの設定から許可してください。") }
        // 既存予約の上書きで目覚ましを失わないよう、初版は一件ずつ予約する。
        guard try manager.alarms.isEmpty else { throw AppIssue("予約済みのアラームがあります。先に一覧から取り消してください。") }
        let stop = AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.circle")
        let attributes = AlarmAttributes<WakeMetadata>(
            presentation: AlarmPresentation(alert: AlarmPresentation.Alert(title: "おはようございます", stopButton: stop)),
            metadata: WakeMetadata(), tintColor: .mint)
        let configuration = AlarmManager.AlarmConfiguration<WakeMetadata>.alarm(
            schedule: .fixed(date), attributes: attributes,
            stopIntent: nil, secondaryIntent: nil, sound: .default)
        _ = try await manager.schedule(id: UUID(), configuration: configuration)
    }

    func cancel(_ id: UUID) throws { try manager.cancel(id: id) }
    func current() throws -> [Alarm] { try manager.alarms }
}
