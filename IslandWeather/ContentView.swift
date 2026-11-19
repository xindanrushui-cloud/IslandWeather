import ActivityKit
import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var currentActivity: Activity<IslandWeatherAttributes>?
    @State private var weather: WeatherData?
    @State private var isLoading = false
    @State private var showPermissionAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var isRunning: Bool { currentActivity != nil }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 标题区
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue)
                        .frame(width: 96, height: 96)
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text("岛天气")
                    .font(.largeTitle.bold())
                Text("灵动岛实时显示温度和天气")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 当前天气卡片
            if let weather {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: weather.iconName)
                            .foregroundStyle(.blue)
                        Text("\(Int(weather.temperature.rounded()))°")
                            .font(.system(size: 48, weight: .bold))
                        Text(weather.condition)
                            .font(.title3)
                    }
                    Text("\(weather.placeName) · 今日 \(Int(weather.low.rounded()))° ~ \(Int(weather.high.rounded()))°")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("更新于 \(weather.updatedAt, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if weather.isFallback {
                        Text("定位不可用，显示福州天气")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
            } else if isLoading {
                ProgressView("正在获取天气…")
                    .padding()
            } else {
                Text("还没有天气数据，点下方按钮获取")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 启动 / 停止
            Button {
                Task {
                    if isRunning {
                        await stopActivity()
                    } else {
                        await startActivity()
                    }
                }
            } label: {
                Text(isRunning ? "停止天气岛" : "启动天气岛")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.red : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            // 手动刷新
            Button {
                Task { await refreshWeather() }
            } label: {
                Label("刷新天气", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .disabled(isLoading)

            Text(isRunning ? "实时活动运行中 · 灵动岛正在显示天气" : "实时活动未启动")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("提示：iOS 的实时活动最长存活约 8 小时，到期后系统会自动结束。可用快捷指令自动化定时重新启动（见 App 内说明或仓库 README）。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            restoreActivity()
            scheduleBackgroundRefresh()
            Task { await refreshWeather() }
        }
        .alert("实时活动未开启", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在「设置 → 岛天气 → 实时活动」中打开开关，再回到 App 启动天气岛。")
        }
        .alert("获取天气失败", isPresented: $showErrorAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - 天气获取

    /// 取定位 → 拉天气 → 显示；活动在跑时同步更新岛上内容。
    /// 定位不可用/被拒时 fallback 到福州。
    private func refreshWeather() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let coordinate: CLLocationCoordinate2D
        var placeName: String
        var isFallback = false

        if let located = await OneShotLocation().fetch() {
            coordinate = located
            placeName = await WeatherService.reverseGeocodePlaceName(coordinate: located) ?? "当前位置"
            WeatherService.saveLastLocation(located, placeName: placeName)
        } else {
            coordinate = WeatherService.fallbackCoordinate
            placeName = WeatherService.fallbackPlaceName
            isFallback = true
        }

        do {
            let data = try await WeatherService.fetch(
                coordinate: coordinate, placeName: placeName, isFallback: isFallback)
            weather = data
            if let activity = currentActivity {
                await activity.update(ActivityContent(state: data.contentState, staleDate: nil))
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    // MARK: - Live Activity

    /// 启动天气岛：先拉到天气，再带着天气数据启动实时活动。
    private func startActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            showPermissionAlert = true
            return
        }

        await refreshWeather()
        guard let weather else { return }

        let content = ActivityContent(state: weather.contentState, staleDate: nil)
        do {
            if let activity = currentActivity {
                await activity.update(content)
            } else {
                let activity = try Activity<IslandWeatherAttributes>.request(
                    attributes: IslandWeatherAttributes(),
                    content: content,
                    pushType: nil
                )
                currentActivity = activity
            }
            scheduleBackgroundRefresh()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    /// 结束实时活动，灵动岛立即收起。
    private func stopActivity() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    /// App 重开后恢复已在运行的 Activity，避免重复启动。
    private func restoreActivity() {
        currentActivity = Activity<IslandWeatherAttributes>.activities.first
    }
}
