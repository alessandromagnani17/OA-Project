import SwiftUI
import RealityKit

@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // Proprietà per memorizzare il modello 3D corrente
    var currentModel: ModelEntity? = nil
    
    // Metodo per gestire lo stato dello spazio immersivo
    func toggleImmersiveSpace() {
        switch immersiveSpaceState {
        case .closed:
            immersiveSpaceState = .inTransition
        case .open:
            immersiveSpaceState = .inTransition
        case .inTransition:
            break
        }
    }
}
