import SwiftUI

@main
struct RobotHeartApp: App {
    @StateObject private var meshtasticManager = MeshtasticManager()
    @StateObject private var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(meshtasticManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
        }
    }
}
