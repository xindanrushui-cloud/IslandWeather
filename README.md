# 岛天气 IslandWeather

一个带灵动岛实时活动（Live Activity）的天气 App。

打开 App 点「启动天气岛」，灵动岛上出现天气图标 + 当前温度 + 天气状况；**长按灵动岛展开**，能看到大温度、天气状况、今日高低温、地点名和更新时间。锁屏上也会同步显示天气横幅。

天气数据来自免费的 [Open-Meteo](https://open-meteo.com) API，无需 key、无需注册。

## 岛上显示什么

| 位置 | 内容 |
|---|---|
| 灵动岛紧凑视图（左侧） | 天气图标 + 当前温度，如 ☁️ 24° |
| 灵动岛紧凑视图（右侧） | 天气状况文字，如“多云” |
| 长按展开（左上） | 天气图标 + 状况 + 地点名 |
| 长按展开（右上） | 大温度 |
| 长按展开（下方） | 今日高低温 + 更新时间 |
| 锁屏横幅 | 图标 + 温度 + 状况 + 地点 + 高低温 |

## 工程结构

```
IslandWeather.xcodeproj/       Xcode 工程（手写 project.pbxproj，两个 target）
IslandWeather/                 App target（SwiftUI）
  IslandWeatherApp.swift       @main 入口 + BGAppRefreshTask 每小时后台刷新
  ContentView.swift            主界面：启动/停止天气岛、当前天气、手动刷新
  WeatherService.swift         Open-Meteo 请求、WMO 天气代码映射、单次定位
  IslandWeatherAttributes.swift 共享的 ActivityAttributes（同时属于两个 target）
  IslandWeatherIntents.swift   快捷指令动作：启动天气岛 / 停止天气岛
  Info.plist                   NSSupportsLiveActivities、定位权限说明、后台任务标识
  Assets.xcassets/             App 图标（蓝底 + 自绘白云太阳，无侵权素材）
IslandWeatherWidget/           Widget Extension target（WidgetKit）
  IslandWeatherWidgetBundle.swift @main WidgetBundle
  IslandWeatherWidget.swift    ActivityConfiguration + DynamicIsland 展开/紧凑/最小视图
  Info.plist                   NSExtensionPointIdentifier = com.apple.widgetkit-extension
.github/workflows/build.yml   GitHub Actions 无签名编译，打包 IPA
```

- 最低系统 iOS 18.0，Swift 5，无第三方依赖，Xcode 16+ 可编译。
- Bundle ID：`com.xin.islandweather`（占位，自签时会重签成自己的）。
- 不需要特殊 entitlements（本地启动的 Live Activity 不需要推送权限）。

## 定位与天气来源

- 打开 App 刷新天气时，会取一次当前位置（WhenInUse 权限，用完即取，不持续跟踪），再用坐标向 Open-Meteo 请求天气，并用系统逆地理编码显示城市名。
- 定位不可用或被拒绝时，fallback 到福州坐标（26.08, 119.30），界面会注明「定位不可用，显示福州天气」。
- WMO 天气代码转中文状况 + SF Symbol 图标的映射表在 `WeatherService.swift` 的 `mapWeatherCode` 里。

## 刷新策略

1. **打开 App 自动刷新**：每次打开 App 都重新拉天气，活动在跑时同步更新岛上内容。
2. **手动刷新**：App 内「刷新天气」按钮。
3. **后台刷新**：BGAppRefreshTask 每小时尝试刷新一次（尽力而为，iOS 可能节流）。
4. **快捷指令自动化**（绕过 8 小时上限，见下）。

## 8 小时过期与快捷指令自动化

iOS 的实时活动最长存活约 8 小时，到期后系统会自动结束，岛上的天气消失——这是苹果的限制，所有 App 都一样。

「岛天气」在快捷指令里暴露了「启动天气岛」动作，可以配自动化定时重开：

1. 打开「快捷指令」App → 底部「自动化」→ 右上角 ＋ →「特定时间」。
2. 设一个时间（例如每天 07:00），下一步选「启动天气岛」动作，关闭「运行前询问」，保存。
3. 再建两个自动化，时间分别设为 15:00 和 23:00，同样运行「启动天气岛」。
4. 这样每天 7 点、15 点、23 点各重开一次，岛上的天气基本全天不断（每次重开都会拉最新天气）。

注意：自动化里跑的是后台动作，不打开 App；它用的是 App 里上次保存的定位（没有则用福州）。

## 用 GitHub Actions 编译（没有 Mac 也能编）

1. 在 GitHub 新建一个仓库，把整个工程推上去。
2. 推到 `main` 分支后，仓库的 **Actions** 页会自动跑 `Build IslandWeather`（也可以点 **Run workflow** 手动跑）。
3. 跑完后在那次运行的页面底部 **Artifacts** 里下载 `IslandWeather-unsigned-ipa`，解压得到 `IslandWeather.ipa`（无签名版）。

## 用 SideStore / XSign 自签安装

1. 把 `IslandWeather.ipa` 传到 iPhone（隔空投送 / 文件 App / 网盘都行）。
2. 用 SideStore 或 XSign 选自己的 Apple ID 签名安装。
3. 首次打开 App 时，系统会问是否允许实时活动和定位，点允许；如果之前拒绝过，去「设置 → 岛天气」里打开「实时活动」和「位置」。
4. 打开 App 点「启动天气岛」，灵动岛上就能看到天气。

免费 Apple ID 签名 7 天过期，过期后用 SideStore 续签即可。
