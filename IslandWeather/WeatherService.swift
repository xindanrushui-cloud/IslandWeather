import CoreLocation
import Foundation

/// 从 Open-Meteo 拉取天气，并做 WMO 天气代码 → 中文状况的映射。
///
/// Open-Meteo（https://open-meteo.com）是免费天气 API，无需 key、无需注册，
/// 非商业用途可直接调用。定位失败时 fallback 到福州坐标。

struct WeatherData {
    var temperature: Double
    var condition: String
    var iconName: String
    var high: Double
    var low: Double
    var placeName: String
    var updatedAt: Date
    var isFallback: Bool
}

enum WeatherService {

    /// 福州坐标（用户在福建；定位不可用/被拒时的 fallback）。
    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 26.08, longitude: 119.30)
    static let fallbackPlaceName = "福州"

    /// UserDefaults 里存的上次成功定位（供快捷指令动作与后台刷新复用，
    /// 它们跑在后台拿不到实时定位）。
    private static let lastLatKey = "IslandWeather.lastLatitude"
    private static let lastLonKey = "IslandWeather.lastLongitude"
    private static let lastPlaceKey = "IslandWeather.lastPlaceName"

    static func saveLastLocation(_ coordinate: CLLocationCoordinate2D, placeName: String) {
        let defaults = UserDefaults.standard
        defaults.set(coordinate.latitude, forKey: lastLatKey)
        defaults.set(coordinate.longitude, forKey: lastLonKey)
        defaults.set(placeName, forKey: lastPlaceKey)
    }

    static func lastKnownLocation() -> (coordinate: CLLocationCoordinate2D, placeName: String) {
        let defaults = UserDefaults.standard
        let lat = defaults.double(forKey: lastLatKey)
        let lon = defaults.double(forKey: lastLonKey)
        if lat != 0, lon != 0 {
            return (CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    defaults.string(forKey: lastPlaceKey) ?? "当前位置")
        }
        return (fallbackCoordinate, fallbackPlaceName)
    }

    // MARK: - Open-Meteo 请求

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
        }
        let current: Current
        let daily: Daily
    }

    /// 拉取指定坐标的天气。调用方负责提供坐标与地点名。
    static func fetch(coordinate: CLLocationCoordinate2D, placeName: String, isFallback: Bool) async throws -> WeatherData {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherError.badResponse
        }
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
        let mapped = mapWeatherCode(forecast.current.weather_code)
        return WeatherData(
            temperature: forecast.current.temperature_2m,
            condition: mapped.condition,
            iconName: mapped.iconName,
            high: forecast.daily.temperature_2m_max.first ?? forecast.current.temperature_2m,
            low: forecast.daily.temperature_2m_min.first ?? forecast.current.temperature_2m,
            placeName: placeName,
            updatedAt: Date(),
            isFallback: isFallback
        )
    }

    /// 用上次保存的定位（或福州 fallback）拉天气。供快捷指令动作与后台刷新使用。
    static func fetchWithLastLocation() async throws -> WeatherData {
        let last = lastKnownLocation()
        let isFallback = (last.coordinate.latitude == fallbackCoordinate.latitude
            && last.coordinate.longitude == fallbackCoordinate.longitude
            && last.placeName == fallbackPlaceName)
        return try await fetch(coordinate: last.coordinate, placeName: last.placeName, isFallback: isFallback)
    }

    // MARK: - WMO 天气代码映射

    /// WMO 天气代码 → （中文状况，SF Symbol 名）。
    static func mapWeatherCode(_ code: Int) -> (condition: String, iconName: String) {
        switch code {
        case 0:
            return ("晴", "sun.max.fill")
        case 1:
            return ("多云", "cloud.sun.fill")
        case 2:
            return ("多云", "cloud.sun.fill")
        case 3:
            return ("阴", "cloud.fill")
        case 45, 48:
            return ("雾", "cloud.fog.fill")
        case 51, 53, 55:
            return ("毛毛雨", "cloud.drizzle.fill")
        case 56, 57:
            return ("冻毛毛雨", "cloud.sleet.fill")
        case 61:
            return ("小雨", "cloud.rain.fill")
        case 63:
            return ("中雨", "cloud.rain.fill")
        case 65:
            return ("大雨", "cloud.heavyrain.fill")
        case 66, 67:
            return ("冻雨", "cloud.sleet.fill")
        case 71:
            return ("小雪", "cloud.snow.fill")
        case 73:
            return ("中雪", "cloud.snow.fill")
        case 75:
            return ("大雪", "cloud.snow.fill")
        case 77:
            return ("雪粒", "cloud.snow.fill")
        case 80:
            return ("小阵雨", "cloud.sun.rain.fill")
        case 81:
            return ("阵雨", "cloud.sun.rain.fill")
        case 82:
            return ("暴雨", "cloud.heavyrain.fill")
        case 85, 86:
            return ("阵雪", "cloud.snow.fill")
        case 95:
            return ("雷阵雨", "cloud.bolt.rain.fill")
        case 96, 99:
            return ("雷阵雨伴冰雹", "cloud.bolt.rain.fill")
        default:
            return ("未知", "cloud.fill")
        }
    }

    // MARK: - 逆地理编码（坐标 → 城市名）

    /// 把坐标解析成城市名；失败返回 nil，调用方用默认地点名。
    static func reverseGeocodePlaceName(coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let place = placemarks.first else { return nil }
            // 优先市级名称，其次区县，最后行政区。
            return place.locality ?? place.subLocality ?? place.administrativeArea
        } catch {
            return nil
        }
    }
}

enum WeatherError: Error, LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "天气服务返回异常，请稍后再试。"
        }
    }
}

// MARK: - 单次定位（用完即取，不持续跟踪）

/// 一次性取当前位置：请求授权 → 取一次坐标 → 停。
/// 授权被拒、定位失败或 10 秒超时都返回 nil，调用方 fallback 到福州。
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetch() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { cont in
            self.continuation = cont
            let status = manager.authorizationStatus
            if status == .denied || status == .restricted {
                finish(nil)
                return
            }
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            // 已授权时直接取一次；未授权时等弹窗结果，
            // locationManagerDidChangeAuthorization 里会再触发一次。
            manager.requestLocation()
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self.finish(nil)
            }
        }
    }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 授权弹窗未出结果时 requestLocation 会先失败一次，
        // 等 didChangeAuthorization 回调里再取；这里只在已确定授权状态时才结束。
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways
            || status == .denied || status == .restricted {
            finish(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(nil)
        default:
            break
        }
    }
}
