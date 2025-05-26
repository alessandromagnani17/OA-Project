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
    
    // Manager per i marker e il piano di taglio
    var markerManager = SimpleMarkerManager()
    
    // Metodo semplificato per gestire lo stato dello spazio immersivo
    func toggleImmersiveSpace() {
        if immersiveSpaceState != .inTransition {
            immersiveSpaceState = .inTransition
        }
    }
    
    // Metodo per pulire tutti i marker
    func clearAllMarkers() {
        for marker in markerManager.markers {
            marker.removeFromParent()
        }
        markerManager.markers.removeAll()
        markerManager.cuttingPlane?.removeFromParent()
        markerManager.cuttingPlane = nil
        print("Tutti i marker sono stati rimossi")
    }
    
    // Metodo per ottenere il numero di marker correnti
    var markerCount: Int {
        return markerManager.markers.count
    }
    
    // Metodo per verificare se il piano di taglio è attivo
    var isCuttingPlaneActive: Bool {
        return markerManager.cuttingPlane != nil
    }
}

// Manager semplificato per i marker
@MainActor
@Observable
class SimpleMarkerManager {
    var markers: [Entity] = []
    var cuttingPlane: Entity? = nil
}
