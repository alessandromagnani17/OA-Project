import SwiftUI
import RealityKit

@MainActor
@Observable
class AppModel {
    // ID dello spazio immersivo
    let immersiveSpaceID = "ImmersiveSpace"
    
    // Enum per lo stato dello spazio immersivo
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    // Stato corrente dello spazio immersivo
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // Proprietà per memorizzare il modello 3D corrente
    var currentModel: ModelEntity? = nil
    
    // Proprietà per scala e posizionamento del modello
    var modelScale: Float = 1.0
    var modelCenter: SIMD3<Float> = .zero
    
    // Metodo semplificato per gestire lo stato dello spazio immersivo
    func toggleImmersiveSpace() {
        if immersiveSpaceState != .inTransition {
            immersiveSpaceState = .inTransition
        }
    }
}
