import Foundation

extension TimeInterval {
    public static func milliseconds(_ value: Int) -> TimeInterval {
        TimeInterval((Double(value) / 1000.0))
    }
    public static func seconds(_ value: Int) -> TimeInterval {
        TimeInterval(value)
    }
    public static func minutes(_ value: Int) -> TimeInterval {
        TimeInterval(value * 60)
    }
    public static func hours(_ value: Int) -> TimeInterval {
        TimeInterval(value * 60 * 60)
    }
    public static func days(_ value: Int) -> TimeInterval {
        TimeInterval(value * 60 * 60 * 24)
    }
}
