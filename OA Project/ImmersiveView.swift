import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        RealityView { content in
            if let model = appModel.currentModel {
                print("Configurazione vista immersiva...")
                
                // Crea un'ancora relativa alla posizione dell'utente
                let anchorEntity = AnchorEntity()
                anchorEntity.position = [0, 0, -1.0]
                
                // Clona il modello per l'uso nello spazio immersivo
                let modelClone = model.clone(recursive: true)
                
                // Posiziona il modello di fronte all'utente a una distanza di 1 metro
                modelClone.position = [0, 0, -1.0]
                print("Modello immersivo posizionato a: \(modelClone.position)")
                
                // Aggiungi il modello all'ancora
                anchorEntity.addChild(modelClone)
                
                // Aggiungi l'ancora alla scena
                content.add(anchorEntity)
                print("Modello aggiunto alla vista immersiva")
            } else {
                print("Nessun modello disponibile per la vista immersiva")
            }
        }
    }
}

// Estensione per le notifiche
extension Notification.Name {
    static let closeModelViewer = Notification.Name("CloseModelViewer")
}
