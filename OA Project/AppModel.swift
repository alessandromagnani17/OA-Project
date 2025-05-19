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
    
    // Proprietà aggiuntive per il modello 3D
    var modelScale: Float = 1.0
    var modelCenter: SIMD3<Float> = .zero
    var holographicMode: Bool = true // Abilita il rendering olografico
    
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
