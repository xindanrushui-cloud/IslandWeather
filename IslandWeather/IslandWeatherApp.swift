import ActivityKit
import BackgroundTasks
import SwiftUI

/// 后台刷新任务的标识，需与 Info.plist 里的
/// BGTaskSchedulerPermittedIdentifiers 一致。
let weatherRefreshTaskID = "com.xin.islandweather.refresh"

@main
struct IslandWeatherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 每小时后台刷新：拉最新天气，更新正在跑的实时活动。
        // iOS 可能节流后台任务，这是尽力而为的刷新；
        // 可靠的续命方式是快捷指令自动化（见 README）。
        .backgroundTask(.appRefresh(weatherRefreshTaskID)) {
            await refreshWeatherInBackground()
            scheduleBackgroundRefresh()
        }
    }
}

/// 提交一次后台刷新请求（最早 1 小时后执行）。
func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: weatherRefreshTaskID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        // 提交失败（如系统节流）不报错，下次打开 App 时再提交。
        print("IslandWeather: 后台刷新提交失败：\(error)")
    }
}

/// 后台任务里做的事：用上次保存的定位拉天气，更新已在跑的活动。
/// 没有活动在跑时什么都不做（后台不允许随意新建实时活动）。
func refreshWeatherInBackground() async {
    guard let activity = Activity<IslandWeatherAttributes>.activities.first else {
        return
    }
    do {
        let weather = try await WeatherService.fetchWithLastLocation()
        await activity.update(ActivityContent(state: weather.contentState, staleDate: nil))
    } catch {
        print("IslandWeather: 后台天气刷新失败：\(error)")
    }
}

extension WeatherData {
    /// 转成实时活动的状态。
    var contentState: IslandWeatherAttributes.ContentState {
        IslandWeatherAttributes.ContentState(
            temperature: temperature,
            condition: condition,
            iconName: iconName,
            high: high,
            low: low,
            placeName: placeName,
            updatedAt: updatedAt,
            isFallback: isFallback
        )
    }
}
