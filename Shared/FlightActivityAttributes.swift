import ActivityKit
import Foundation

/// 灵动岛 / Live Activity 的航班属性（App 与 Widget 共享）
public struct FlightActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 本段专注的起止时间，系统原生渲染倒计时/进度，无需刷新
        public var segmentStart: Date
        public var segmentEnd: Date
        /// 整条旅程的航线进度（接力时体现检查点）
        public var fractionStart: Double
        public var fractionEnd: Double

        public init(segmentStart: Date, segmentEnd: Date, fractionStart: Double, fractionEnd: Double) {
            self.segmentStart = segmentStart
            self.segmentEnd = segmentEnd
            self.fractionStart = fractionStart
            self.fractionEnd = fractionEnd
        }
    }

    public var originCode: String
    public var destCode: String
    public var originCity: String
    public var destCity: String
    public var flightNumber: String
    public var carrierName: String
    public var cabinCode: String

    public init(originCode: String, destCode: String, originCity: String, destCity: String,
                flightNumber: String, carrierName: String, cabinCode: String) {
        self.originCode = originCode
        self.destCode = destCode
        self.originCity = originCity
        self.destCity = destCity
        self.flightNumber = flightNumber
        self.carrierName = carrierName
        self.cabinCode = cabinCode
    }
}
