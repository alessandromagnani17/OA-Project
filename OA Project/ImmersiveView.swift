import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var dragAmount = CGSize.zero
    
    var body: some View {
        RealityView { content in
            if let model = appModel.currentModel {
                print("Configurazione vista immersiva...")
                
                // Crea un'ancora relativa alla posizione dell'utente
                let anchorEntity = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.5, 0.5]))
                
                // Posiziona l'ancora di fronte all'utente
                // La spostiamo un po' verso l'alto e in avanti per una migliore visualizzazione
                anchorEntity.position = [0, 1.0, -1.5]
                
                // Clona il modello per l'uso nello spazio immersivo
                let modelClone = model.clone(recursive: true)
                
                // Aggiungi un componente in modo da poterlo identificare per le interazioni
                modelClone.name = "ModelToRotate"
                
                // Applica materiale olografico a tutte le entità
                applyHolographicMaterial(to: modelClone)
                
                // Aggiungi il modello all'ancora
                anchorEntity.addChild(modelClone)
                
                // Aggiungi l'ancora alla scena
                content.add(anchorEntity)
                print("Modello aggiunto alla vista immersiva")
                
                // Aggiungi illuminazione alla scena
                addLighting(to: content)
            } else {
                print("Nessun modello disponibile per la vista immersiva")
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let rotationAmount = Float(value.translation.width - dragAmount.width) / 200.0
                    if let model = appModel.currentModel {
                        // Utilizziamo l'asse Y per la rotazione orizzontale
                        let rotationY = simd_quatf(angle: rotationAmount, axis: [0, 1, 0])
                        model.transform.rotation = model.transform.rotation * rotationY
                        dragAmount = value.translation
                    }
                }
                .onEnded { _ in
                    dragAmount = .zero
                }
        )
    }
    
    // Applica un materiale olografico traslucido a tutte le entità dell'albero
    private func applyHolographicMaterial(to entity: Entity) {
        if let modelEntity = entity as? ModelEntity {
            // Crea un materiale olografico con effetto traslucido
            var holographicMaterial = SimpleMaterial()
            holographicMaterial.color = .init(tint: UIColor.cyan.withAlphaComponent(0.7))
            holographicMaterial.roughness = 0.2
            holographicMaterial.metallic = 0.8
            
            // Applica il materiale
            modelEntity.model?.materials = [holographicMaterial]
        }
        
        // Applica ricorsivamente a tutti i figli
        for child in entity.children {
            applyHolographicMaterial(to: child)
        }
    }
    
    // Aggiunge illuminazione a una scena RealityKit
    private func addLighting(to content: RealityViewContent) {
        // Luce principale bianca dall'alto
        let mainLight = Entity()
        mainLight.components[PointLightComponent.self] = PointLightComponent(
            color: .white,
            intensity: 1000,
            attenuationRadius: 10
        )
        mainLight.position = [0, 2, 0]
        content.add(mainLight)
        
        // Luce accent ciano per effetto olografico
        let accentLight = Entity()
        accentLight.components[PointLightComponent.self] = PointLightComponent(
            color: .cyan,
            intensity: 800,
            attenuationRadius: 5
        )
        accentLight.position = [1, 0, -1]
        content.add(accentLight)
        
        // Luce di riempimento dall'altro lato
        let fillLight = Entity()
        fillLight.components[PointLightComponent.self] = PointLightComponent(
            color: .white.withAlphaComponent(0.3),
            intensity: 500,
            attenuationRadius: 7
        )
        fillLight.position = [-1, 1, 0]
        content.add(fillLight)
    }
}
