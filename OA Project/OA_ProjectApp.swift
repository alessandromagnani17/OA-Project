import SwiftUI

@main
struct OA_ProjectApp: App {
    // Istanza del modello dell'applicazione
    @State private var appModel = AppModel()

    var body: some Scene {
        // Finestra principale dell'applicazione
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        // Configurazione dello spazio immersivo
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
