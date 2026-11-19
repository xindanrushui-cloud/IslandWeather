import ActivityKit
import AppIntents
import Foundation

/// 快捷指令动作：启动天气岛。
///
/// 供「快捷指令」自动化调用（例如定时触发，每 8 小时重开一次，
/// 绕过 iOS 实时活动 8 小时上限）。后台拉取天气（用 App 里上次
/// 保存的定位，没有则用福州），有活动在跑则更新它，不重复启动。
/// Intent 在后台运行，不打开 App。
struct StartWeatherIslandIntent: AppIntent {
    static var title: LocalizedStringResource = "启动天气岛"
    static var description = IntentDescription("启动岛天气的灵动岛实时活动，岛上显示当前温度和天气。")

    func perform() async throws -> some IntentResult {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw WeatherIntentError.activitiesNotEnabled
        }

        let weather = try await WeatherService.fetchWithLastLocation()
        let content = ActivityContent(state: weather.contentState, staleDate: nil)

        if let activity = Activity<IslandWeatherAttributes>.activities.first {
            await activity.update(content)
        } else {
            _ = try Activity<IslandWeatherAttributes>.request(
                attributes: IslandWeatherAttributes(),
                content: content,
                pushType: nil
            )
        }
        return .result()
    }
}

/// 快捷指令动作：停止天气岛。
struct StopWeatherIslandIntent: AppIntent {
    static var title: LocalizedStringResource = "停止天气岛"
    static var description = IntentDescription("结束岛天气的灵动岛实时活动。")

    func perform() async throws -> some IntentResult {
        for activity in Activity<IslandWeatherAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

/// 岛天气快捷指令动作的报错。
enum WeatherIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case activitiesNotEnabled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .activitiesNotEnabled:
            return "实时活动未开启，请在「设置 → 岛天气 → 实时活动」中打开开关。"
        }
    }
}

/// 把两个动作暴露给快捷指令与 Siri。
struct IslandWeatherShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWeatherIslandIntent(), phrases: [
            "用${applicationName}启动天气岛",
        ])
        AppShortcut(intent: StopWeatherIslandIntent(), phrases: [
            "用${applicationName}停止天气岛",
        ])
    }
}
