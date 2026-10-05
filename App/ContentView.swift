import SwiftUI
import Charts
import AlarmKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("wakeHour") private var hour = 7
    @AppStorage("wakeMinute") private var minute = 0
    @AppStorage("windowMinutes") private var window = 30
    @AppStorage("predictionEnabled") private var prediction = false
    @State private var pendingDate: Date?
    @State private var pendingReason = ""
    @State private var confirm = false

    private var clock: Binding<Date> {
        Binding(get: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute))! }, set: {
            hour = Calendar.current.component(.hour, from: $0)
            minute = Calendar.current.component(.minute, from: $0)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("SLEEP WINDOW", systemImage: "moon.stars.fill").foregroundStyle(.mint).font(.caption.bold())
                        Text("眠りを知って、\n朝を迎える。").font(.largeTitle.bold())
                        Text("Apple Watchの睡眠履歴 × iPhoneのアラーム").font(.subheadline).foregroundStyle(.secondary)
                    }
                    alarmCard
                    historyCard
                    VStack(alignment: .leading, spacing: 8) {
                        Text("この試作版について").font(.headline)
                        Text("睡眠の記録はApple Watchの標準睡眠機能が行います。このアプリは同期済みの記録を読み込みます。今夜の睡眠段階をリアルタイムで判定する機能はありません。履歴予測は実験的なもので、目覚めやすさの改善は未検証です。")
                        Text("初回は60秒テストで音を確認してください。実機検証が済むまでは標準「時計」のアラームも併用してください。")
                        Button("60秒後のアラームをテスト") {
                            pendingDate = Date().addingTimeInterval(60)
                            pendingReason = "60秒後に実際のアラームを鳴らします。"
                            confirm = true
                        }.disabled(model.busy || !model.alarms.isEmpty)
                        Text("データは端末内で処理します。外部サーバーへの送信はありません。")
                    }.font(.footnote).foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(Color(red: 0.035, green: 0.06, blue: 0.11))
            .navigationTitle("Sleep Window").navigationBarTitleDisplayMode(.inline)
            .task {
                model.syncAlarms()
                for await _ in AlarmManager.shared.alarmUpdates { model.syncAlarms() }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { model.syncAlarms() } }
            .alert("アラームを予約", isPresented: $confirm) {
                Button("予約する") { if let date = pendingDate { Task { await model.reserve(date) } } }
                Button("戻る", role: .cancel) {}
            } message: {
                Text("\(pendingDate?.formatted(date: .abbreviated, time: .shortened) ?? "")\n\(pendingReason)\n予約後は時刻を自動変更しません。")
            }
            .alert("確認してください", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }

    private var alarmCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("次の起床", systemImage: "sunrise.fill").font(.headline)
            DatePicker("起床期限", selection: clock, displayedComponents: .hourAndMinute)
            Toggle("履歴から時刻を予測（試験）", isOn: $prediction)
            if prediction {
                Picker("早めに起こしてよい範囲", selection: $window) {
                    ForEach([10, 20, 30, 45, 60], id: \.self) { Text("\($0)分前から").tag($0) }
                }
                Text("過去14日間の同時刻のコア睡眠を参考にします。データ不足なら起床期限に予約します。固定90分周期は使いません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                let now = Date()
                guard let deadline = WakePlanner.nextWake(hour: hour, minute: minute, now: now) else { return }
                if prediction {
                    let result = WakePlanner.choose(deadline: deadline, windowMinutes: window, now: now, slices: model.selected)
                    pendingDate = result.date; pendingReason = result.reason
                } else {
                    pendingDate = deadline; pendingReason = "指定した起床時刻を使用します。"
                }
                confirm = true
            } label: {
                Text("次のアラームを予約").frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.busy || !model.alarms.isEmpty)
            ForEach(model.alarms, id: \.id) { alarm in
                HStack {
                    VStack(alignment: .leading) {
                        Text("予約済み").font(.caption).foregroundStyle(.mint)
                        if case let .fixed(date)? = alarm.schedule {
                            Text(date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                        } else { Text("システムのアラーム") }
                    }
                    Spacer()
                    Button("取消", role: .destructive) { model.cancel(alarm.id) }.disabled(model.busy)
                }
            }
            Text(model.message).font(.caption).foregroundStyle(.secondary)
            if model.busy { ProgressView() }
        }.padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("睡眠の記録", systemImage: "waveform.path").font(.headline)
                Spacer()
                Button("接続・更新") { Task { await model.connect() } }.disabled(model.busy)
            }
            if !model.sources.isEmpty {
                Picker("記録元", selection: $model.source) {
                    ForEach(model.sources, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                let end = Date()
                let start = end.addingTimeInterval(-86400)
                let recent = model.selected.filter { $0.end > start && $0.start < end }
                let duration = WakePlanner.sleepDuration(recent, from: start, to: end)
                Text("直近24時間  \(Int(duration) / 3600)時間\(Int(duration) % 3600 / 60)分")
                    .font(.title2.bold())
                if recent.isEmpty {
                    Text("直近24時間の記録はありません。Watchの同期後に更新してください。")
                } else {
                    Chart(recent) { slice in
                        RectangleMark(xStart: .value("開始", max(start, slice.start)), xEnd: .value("終了", min(end, slice.end)), y: .value("段階", slice.stage.label))
                            .foregroundStyle(by: .value("段階", slice.stage.label))
                    }.chartXScale(domain: start...end).chartLegend(.hidden).frame(height: 170)
                        .accessibilityLabel("睡眠段階の記録。詳細は下の一覧。")
                }
                DisclosureGroup("読み込んだ記録 \(model.selected.count)件") {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.selected.reversed()) { slice in
                            VStack(alignment: .leading) {
                                Text(slice.stage.label).font(.subheadline.bold())
                                Text("\(slice.start.formatted(date: .abbreviated, time: .shortened)) → \(slice.end.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("まだ記録を読み込んでいません。\nApple Watchで睡眠を記録し、ヘルスケアの読み取りを許可してください。")
                    .foregroundStyle(.secondary)
            }
            if let date = model.loadedAt {
                Text("最終読込 \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }
}
