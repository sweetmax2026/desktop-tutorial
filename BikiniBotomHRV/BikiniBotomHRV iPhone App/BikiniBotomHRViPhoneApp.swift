import SwiftUI

@main
struct BikiniBotomHRViPhoneApp: App {
    @StateObject private var hrvStore = PhoneHRVStore()

    var body: some Scene {
        WindowGroup {
            PhoneDashboardView(store: hrvStore)
                .task {
                    hrvStore.requestAuthorizationAndLoad()
                }
        }
    }
}
