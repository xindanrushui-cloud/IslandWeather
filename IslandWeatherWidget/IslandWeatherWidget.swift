import ActivityKit
import SwiftUI
import WidgetKit

/// 岛天气的实时活动视图：锁屏横幅 + 灵动岛展开/紧凑/最小三种形态。
///
/// 紧凑视图：左侧天气图标 + 温度，右侧天气状况文字。
/// 展开视图：左上地点 + 状况，右上大温度，下方今日高低温 + 更新时间。
struct IslandWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandWeatherAttributes.self) { context in
            // 锁屏横幅视图
            HStack(spacing: 12) {
                Image(systemName: context.state.iconName)
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(Int(context.state.temperature.rounded()))°")
                            .font(.title3.bold())
                        Text(context.state.condition)
                            .font(.headline)
                    }
                    Text("\(context.state.placeName) · 今日 \(Int(context.state.low.rounded()))° ~ \(Int(context.state.high.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开视图：左上地点 + 状况
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: context.state.iconName)
                                .foregroundStyle(.blue)
                            Text(context.state.condition)
                                .font(.headline)
                        }
                        Text(context.state.placeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                // 展开视图：右上大温度
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.temperature.rounded()))°")
                        .font(.largeTitle.bold())
                }
                // 展开视图：下方高低温 + 更新时间
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("今日 \(Int(context.state.low.rounded()))° ~ \(Int(context.state.high.rounded()))°")
                            .font(.subheadline)
                        Spacer()
                        Text("更新于 \(context.state.updatedAt, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: context.state.iconName)
                        .foregroundStyle(.blue)
                    Text("\(Int(context.state.temperature.rounded()))°")
                        .font(.caption.weight(.semibold))
                }
            } compactTrailing: {
                Text(context.state.condition)
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: context.state.iconName)
                    .foregroundStyle(.blue)
            }
            .keylineTint(.blue)
        }
    }
}
