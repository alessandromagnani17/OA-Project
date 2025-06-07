import SwiftUI
import RealityKit
import ARKit

// Classe per gestire i marker e il piano di taglio
@MainActor
@Observable
class MarkerManager {
    // Array dei marker posizionati
    var markers: [MarkerEntity] = []
    
    // Piano di taglio corrente
    var cuttingPlane: Entity? = nil
    
    // Stato del pinch gesture
    var isPinchActive: Bool = false
    
    // Numero massimo di marker
    private let maxMarkers = 3
    
    // Aggiunge un nuovo marker alla posizione specificata
    func addMarker(at position: SIMD3<Float>) {
        // Se abbiamo già 3 marker, rimuoviamo il più vecchio
        if markers.count >= maxMarkers {
            let oldestMarker = markers.removeFirst()
            oldestMarker.removeFromParent()
        }
        
        // Crea un nuovo marker
        let marker = MarkerEntity(position: position, index: markers.count)
        markers.append(marker)
        
        print("Marker aggiunto alla posizione: \(position)")
        
        // Se abbiamo 3 marker, crea/aggiorna il piano di taglio
        if markers.count == 3 {
            updateCuttingPlane()
        }
    }
    
    // Rimuove tutti i marker
    func clearAllMarkers() {
        for marker in markers {
            marker.removeFromParent()
        }
        markers.removeAll()
        
        // Rimuovi il piano di taglio
        cuttingPlane?.removeFromParent()
        cuttingPlane = nil
        
        print("Tutti i marker sono stati rimossi")
    }
    
    // Aggiorna il piano di taglio basato sui 3 marker
    private func updateCuttingPlane() {
        guard markers.count == 3 else { return }
        
        let pos1 = markers[0].position
        let pos2 = markers[1].position
        let pos3 = markers[2].position
        
        // Calcola due vettori del piano
        let vector1 = pos2 - pos1
        let vector2 = pos3 - pos1
        
        // Calcola la normale del piano usando il prodotto vettoriale
        let normal = normalize(cross(vector1, vector2))
        
        // Calcola il centro del piano
        let center = (pos1 + pos2 + pos3) / 3
        
        // Rimuovi il piano precedente se esiste
        cuttingPlane?.removeFromParent()
        
        // Crea il nuovo piano di taglio
        cuttingPlane = createCuttingPlaneEntity(center: center, normal: normal, size: 1.0)
        
        print("Piano di taglio aggiornato con normale: \(normal) e centro: \(center)")
    }
    
    // Crea l'entità del piano di taglio
    private func createCuttingPlaneEntity(center: SIMD3<Float>, normal: SIMD3<Float>, size: Float) -> Entity {
        let planeEntity = Entity()
        
        // Crea una mesh per il piano
        let planeMesh = MeshResource.generatePlane(width: size, depth: size)
        
        // Materiale semi-trasparente per il piano
        var planeMaterial = SimpleMaterial()
        planeMaterial.color = .init(tint: UIColor.red.withAlphaComponent(0.3))
        planeMaterial.roughness = 0.8
        planeMaterial.metallic = 0.0
        
        let planeModelEntity = ModelEntity(mesh: planeMesh, materials: [planeMaterial])
        
        // Posiziona il piano
        planeEntity.position = center
        
        // Orienta il piano secondo la normale
        let defaultNormal = SIMD3<Float>(0, 1, 0) // Normale di default per un piano orizzontale
        let rotation = simd_quatf(from: defaultNormal, to: normal)
        planeEntity.orientation = rotation
        
        planeEntity.addChild(planeModelEntity)
        
        return planeEntity
    }
    
    // Ottieni tutti i marker come entità da aggiungere alla scena
    func getMarkerEntities() -> [Entity] {
        return markers.map { $0 as Entity }
    }
}

// Entità personalizzata per i marker
class MarkerEntity: Entity, HasModel {
    let markerIndex: Int
    
    init(position: SIMD3<Float>, index: Int) {
        self.markerIndex = index
        super.init()
        
        // Crea la geometria del marker (sfera piccola)
        let sphereMesh = MeshResource.generateSphere(radius: 0.02)
        
        // Materiale colorato per distinguere i marker
        let colors: [UIColor] = [.red, .green, .blue]
        let color = colors[index % colors.count]
        
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.roughness = 0.3
        material.metallic = 0.7
        
        // Nota: emissiveColor non è disponibile in SimpleMaterial
        // Usiamo solo il colore base con alpha per l'effetto
        
        self.components[ModelComponent.self] = ModelComponent(
            mesh: sphereMesh,
            materials: [material]
        )
        
        self.position = position
        
        // Aggiungi un'animazione di pulsazione
        addPulseAnimation()
    }
    
    required init() {
        fatalError("Use init(position:index:) instead")
    }
    
    // Animazione di pulsazione per rendere i marker più visibili
    private func addPulseAnimation() {
        // Animazione semplificata usando Transform
        let originalScale = self.scale
        let enlargedScale = originalScale * 1.2
        
        // Crea un'animazione semplice di scala
        let duration: Float = 1.0
        
        // Usa un'animazione personalizzata più semplice
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startPulseLoop(originalScale: originalScale, enlargedScale: enlargedScale)
        }
    }
    
    private func startPulseLoop(originalScale: SIMD3<Float>, enlargedScale: SIMD3<Float>) {
        // Scala verso l'alto
        let scaleUpTransform = Transform(scale: enlargedScale, rotation: self.orientation, translation: self.position)
        self.move(to: scaleUpTransform, relativeTo: self.parent, duration: 0.5)
        
        // Dopo 0.5 secondi, scala verso il basso
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let scaleDownTransform = Transform(scale: originalScale, rotation: self.orientation, translation: self.position)
            self.move(to: scaleDownTransform, relativeTo: self.parent, duration: 0.5)
            
            // Continua il loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startPulseLoop(originalScale: originalScale, enlargedScale: enlargedScale)
            }
        }
    }
}

// Estensione per calcolare il quaternion di rotazione tra due vettori
extension simd_quatf {
    init(from: SIMD3<Float>, to: SIMD3<Float>) {
        let fromNormalized = normalize(from)
        let toNormalized = normalize(to)
        
        let dot = simd_dot(fromNormalized, toNormalized)
        
        if dot >= 0.999999 {
            // I vettori sono paralleli
            self.init(real: 1, imag: SIMD3<Float>(0, 0, 0))
        } else if dot <= -0.999999 {
            // I vettori sono opposti
            var perpendicular = cross(fromNormalized, SIMD3<Float>(1, 0, 0))
            if simd_length(perpendicular) < 0.01 {
                perpendicular = cross(fromNormalized, SIMD3<Float>(0, 1, 0))
            }
            perpendicular = normalize(perpendicular)
            self.init(angle: .pi, axis: perpendicular)
        } else {
            let axis = normalize(cross(fromNormalized, toNormalized))
            let angle = acos(dot)
            self.init(angle: angle, axis: axis)
        }
    }
}
