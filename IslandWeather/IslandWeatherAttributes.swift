import ActivityKit
import Foundation

/// 岛天气 Live Activity 的共享属性定义。
///
/// 本文件同时加入 App target 与 Widget Extension target，
/// 两边共用同一份定义（在 project.pbxproj 中是同一个 fileRef、
/// 两条 PBXBuildFile 记录）。
struct IslandWeatherAttributes: ActivityAttributes {

    /// 实时活动中会变化的状态（天气数据）。
    public struct ContentState: Codable, Hashable {
        /// 当前温度（℃）。
        var temperature: Double
        /// 天气状况中文，如“多云”。
        var condition: String
        /// SF Symbol 名，如 "cloud.sun.fill"，岛上与锁屏直接用这个画图标。
        var iconName: String
        /// 今日最高温（℃）。
        var high: Double
        /// 今日最低温（℃）。
        var low: Double
        /// 地点名，如“福州”。
        var placeName: String
        /// 数据更新时间。
        var updatedAt: Date
        /// 是否用了福州 fallback（定位不可用时为 true）。
        var isFallback: Bool
    }

    // 没有固定属性：每次启动都拉取最新天气，全部放在 ContentState 里。
}
