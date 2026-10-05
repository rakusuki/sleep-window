# Sleep Window — iPhone + Apple Watch 睡眠履歴アラーム

**v0.1.0 / ソースコード試作版。GitHub ActionsでCoreテスト12件と署名なしiOSシミュレータビルド成功。実機動作は未検証です。**

Apple Watchが標準機能で記録した睡眠段階をiPhoneのHealthKitから読み込み、履歴を表示します。指定時刻、または履歴から計算して利用者が確認した時刻に、AlarmKitで1回のアラームを予約します。

## 重要な実装範囲

- **今夜の睡眠周期をリアルタイムに測定して、浅くなった瞬間に鳴らす機能は未実装です。** Appleの公開APIでは睡眠段階の即時配信を前提にできません。HealthKit更新通知は、保存・同期済みサンプルの更新を知らせる仕組みです。
- Apple Watch側には新しいアプリを入れません。Watch標準の睡眠記録を利用し、iPhone側で読み込みます。
- 履歴予測は「過去の同じ時計時刻にコア睡眠だった割合」という未検証のヒューリスティックです。生理学的な最適時刻、今夜の睡眠段階、目覚めの改善を保証しません。
- 起床期限までに鳴る時刻を事前に1つ予約します。予約後の自動変更・毎日の自動予約・スヌーズはありません。
- 予測機能は初期状態ではオフです。まず固定時刻の実機テストから始めてください。

## 入っている機能

1. 起床期限、早めに起こしてよい範囲（10・20・30・45・60分）の設定と保存。
2. HealthKitの睡眠記録を読み取り、記録元を選択。
3. 直近24時間の睡眠段階グラフと重複を除いた睡眠時間、読み込んだ履歴一覧。
4. 履歴からの時刻候補計算。予約前に日付・時刻・根拠を確認。
5. iOS 26以降のAlarmKitによる予約、システムの予約状態表示、取消。
6. 60秒後の鳴動テスト。予約エラーや権限拒否を画面に表示。
7. 端末内処理。外部通信、アカウント登録、分析SDKなし。

## MacからiPhoneに入れる

必要なもの：iOS 26以降のiPhone、対応するXcode 26以降を動かせるMac、Xcodeで署名できるAppleアカウント。Watchでは標準の睡眠記録を有効にし、段階の記録に対応した機種・OSを使用します。

1. ZIPをMacで展開し、`SleepWindow.xcodeproj`を開きます。
2. 左側のプロジェクトを選択し、TARGETS → SleepWindow → Signing & Capabilitiesを開きます。
3. Teamを自分の開発チームにし、Bundle Identifierを重複しない値（例：`jp.yourname.SleepWindow`）へ変更します。
4. HealthKit capabilityが有効なことを確認します。署名チームでこの機能を使える必要があります。
5. iPhoneを接続して信頼し、必要に応じてiPhoneのデベロッパモードを有効にします。
6. 実行先を接続したiPhoneにしてRun（⌘R）を押します。
7. アプリの「接続・更新」から睡眠データの読み取りを許可します。Watchの記録元を選びます。
8. 「60秒後のアラームをテスト」を押し、予約を確認して、アラーム権限を許可します。
9. iPhoneをロックして実際に鳴ること・停止できることを確認します。
10. 起床期限を設定し、必要なら履歴予測をオンにして、表示された予約時刻を確認します。

このZIPはインストール済みアプリや署名済みIPAではありません。MacのXcodeによるビルド・署名が必要です。TestFlight/App Storeへの配布は未実施です。初回の実機検証までは標準「時計」のアラームも併用してください。

## Apple Watchの準備

iPhoneのヘルスケア／Watchの睡眠設定で、Apple Watchによる睡眠記録を有効にします。就寝時に装着し、翌朝、ヘルスケアで睡眠段階が表示されることを確認してから本アプリで更新してください。

HealthKitは読み取り拒否をアプリから確実に判別できません。記録が空でも「許可済み」「記録が存在しない」と断定しません。読み取り許可、Watchの睡眠設定、同期を確認してください。

## 履歴予測の仕様

- HealthKitから直近15日分を読み込み、候補ごとに過去14日を参照します。
- 起床期限から設定した範囲内を5分刻みで評価します。現在から60秒以内の候補は除外します。
- 選択した1つの記録元だけを使い、各日の同じ時計時刻の睡眠段階を見ます。
- コア・深い・REM・覚醒のいずれか1つがわかる日を観測日とします。段階不明、欠測、矛盾した重複は除外します。同一段階の重複は1日として扱います。
- 3日以上の観測があり、コア睡眠が60%以上だった候補のうち、割合が最大の時刻を選びます。同点なら遅い時刻です。
- 該当候補がなければ指定した起床期限を使います。3日・60%・5分は試作の設計値で、臨床的に検証した値ではありません。
- 候補ごとの観測日数が異なる可能性があります。表示する割合は今夜の確率・信頼度ではありません。
- 就寝時刻の変動、交代勤務、時差、病気などをモデル化していません。タイムゾーンを移動した後は予測をオフにしてください。
- 予約は絶対日時です。予約後のタイムゾーン変更で指定した現地時計時刻へ自動追従しません。取り消して再予約してください。

## 構成

| ファイル | 役割 |
|---|---|
| `App/ContentView.swift` | 日本語UI・履歴グラフ・予約確認 |
| `App/HealthReader.swift` | 読み取り許可・睡眠サンプル取得 |
| `App/AlarmService.swift` | AlarmKitの許可・予約・取消 |
| `App/AppModel.swift` | 読み込み・予約状態・エラー管理 |
| `App/SleepWindowApp.swift` | アプリ入口 |
| `Core/Sources/SleepCore/SleepCore.swift` | 起床候補計算・重複除去 |
| `Core/Tests/SleepCoreTests/WakePlannerTests.swift` | 判定ロジックの12件のテスト |

CoreはXcodeプロジェクトで直接コンパイルします。同じファイルをSwift Packageから単独でテストできます。

```bash
cd Core
swift test
```

署名なしシミュレータ向けビルド確認（Mac、Xcodeが必要）：

```bash
xcodebuild -project SleepWindow.xcodeproj -scheme SleepWindow \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

シミュレータでビルドできても、HealthKitのWatch同期とアラームの実鳴動は実機検証が必要です。

## データと権限

睡眠サンプルはアプリ実行中のメモリに保持し、元データはヘルスケアに残ります。アプリは睡眠データを書き換えません。設定はUserDefaults、アラームはiOSのAlarmKitが管理します。アプリへ戻る際に予約状態を再取得します。履歴は「接続・更新」で更新します。バックグラウンドの常時監視やマイク録音はありません。

## 次の開発段階

真のリアルタイム起床判定には、watchOS側の計測方式、バックグラウンド実行制約、消費電力、測定値と睡眠段階の関係、端末間の配送遅延を検証する必要があります。通常の睡眠計測をワークアウトと偽装して実行する設計は採用していません。初版の履歴予測はこの課題を解決したものではありません。

## 参照したApple公式資料

- [AlarmKitの概要とiOS 26のアラーム](https://developer.apple.com/videos/play/wwdc2025/230/)
- [AlarmKitによる予約](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)
- [睡眠段階のデータ型](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)
- [HealthKitバックグラウンド更新の仕様](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:))

API参照確認日：2026-10-05。実際のSDKとの整合性はXcodeビルドで確認してください。

## License

MIT License。詳細は [LICENSE](LICENSE) を参照してください。
