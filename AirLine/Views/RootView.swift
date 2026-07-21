import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [PlayerProfile]
    @Query private var journeys: [ActiveJourney]
    @State private var engine = FlightEngine.shared

    private var flyingJourney: ActiveJourney? {
        journeys.first(where: { $0.segmentStartAt != nil })
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let profile = profiles.first {
                MainTabs(profile: profile)
                if let journey = flyingJourney {
                    FocusFlightView(journey: journey)
                        .zIndex(5)
                }
            } else {
                OnboardingView()
            }

            if let outcome = engine.pendingOutcome {
                LandingView(outcome: outcome) {
                    engine.pendingOutcome = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: engine.pendingOutcome == nil)
        .preferredColorScheme(.dark)
        .tint(Theme.glow)
        .task {
            #if DEBUG
            DemoSeeder.runIfRequested(context: context)
            // demo 刚起飞的段不要被"冷启动恢复"误判为破戒
            guard !ProcessInfo.processInfo.arguments.contains("--demo-flying") else { return }
            #endif
            engine.recoverOnLaunch(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            engine.handleScenePhase(phase, context: context)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            engine.handleDeviceLocked()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            engine.handleDeviceUnlocked(isAppActive: scenePhase == .active)
        }
    }
}

private struct MainTabs: View {
    let profile: PlayerProfile
    @State private var selection = MainTabs.initialTab

    private static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--demo-tab-fly") { return 1 }
        if args.contains("--demo-tab-me") { return 2 }
        #endif
        return 0
    }

    var body: some View {
        TabView(selection: $selection) {
            MapTabView()
                .tabItem { Label("地图", systemImage: "globe.asia.australia.fill") }
                .tag(0)
            FlyHomeView(profile: profile)
                .tabItem { Label("飞行", systemImage: "airplane") }
                .tag(1)
            MeView(profile: profile)
                .tabItem { Label("我的", systemImage: "person.text.rectangle") }
                .tag(2)
        }
    }
}
