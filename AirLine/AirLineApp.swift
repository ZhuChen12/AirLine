import SwiftData
import SwiftUI

@main
struct AirLineApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            PlayerProfile.self,
            FlightRecord.self,
            CityVisit.self,
            PassportStamp.self,
            ActiveJourney.self,
        ])
    }
}
