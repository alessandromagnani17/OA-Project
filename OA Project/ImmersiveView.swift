import SwiftUI
import RealityKit
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var dragAmount = CGSize.zero
    @State private var session = ARKitSession()
    @State private var handTracking = HandTrackingProvider()
    @State private var lastPinchState = false
    @State private var realityContent: RealityViewContent? = nil
    @State private var pinchStartTime: Date? = nil
    
    // NUOVO: Stato per tracciare se l'utente sta guardando un elemento UI
    @State private var isLookingAtUI = false
    @State private var lastUIInteractionTime: Date = Date.distantPast
    
    var body: some View {
        RealityView { content in
            // Salva il riferimento al content per usarlo dopo
            realityContent = content
            
            if let model = appModel.currentModel {
                print("Configurazione vista immersiva...")
                
                // Crea un'ancora relativa alla posizione dell'utente
                let anchorEntity = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.5, 0.5]))
                
                // Posiziona l'ancora di fronte all'utente
                anchorEntity.position = [0, 1.0, -1.5]
                
                // Clona il modello per l'uso nello spazio immersivo
                let modelClone = model.clone(recursive: true)
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
        } update: { content in
            // RIMOSSO: l'update automatico causava problemi
            // updateMarkersInScene(content: content)
        }
        // NUOVO: Monitora le interazioni UI con un approccio semplificato
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // App torna in primo piano - potrebbe essere interazione UI
            lastUIInteractionTime = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // App va in background
            isLookingAtUI = false
        }
        .task {
            // Avvia il hand tracking
            do {
                if HandTrackingProvider.isSupported {
                    print("Hand tracking supportato, avvio sessione...")
                    try await session.run([handTracking])
                    print("Hand tracking avviato con successo")
                } else {
                    print("Hand tracking non supportato su questo dispositivo")
                }
            } catch {
                print("Errore nell'avvio del hand tracking: \(error)")
            }
        }
        .task {
            // Loop per processare il hand tracking
            await processHandUpdates()
        }
        .onTapGesture { location in
            // TEMPORANEO: per testare senza hand tracking
            // NUOVO: Non creare marker se stiamo guardando l'UI
            if !isLookingAtUI {
                let testPosition = SIMD3<Float>(
                    Float.random(in: -1...1),
                    Float.random(in: 0.5...2),
                    Float.random(in: -2...0)
                )
                addMarker(at: testPosition)
                print("Marker di test aggiunto con tap")
            } else {
                print("Tap ignorato - focus su UI")
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let rotationAmount = Float(value.translation.width - dragAmount.width) / 200.0
                    if let model = appModel.currentModel {
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
    
    // Processa gli aggiornamenti del hand tracking
    private func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let handAnchor = update.anchor
            
            // Processa solo la mano destra
            if handAnchor.chirality == .right {
                await checkPinchGesture(handAnchor: handAnchor)
            }
        }
    }
    
    // MODIFICATO: Controlla il gesto di pinch con rilevamento UI
    private func checkPinchGesture(handAnchor: HandAnchor) async {
        guard let handSkeleton = handAnchor.handSkeleton else { return }
        
        let thumbTip = handSkeleton.joint(.thumbTip)
        let indexTip = handSkeleton.joint(.indexFingerTip)
        
        // Controlla se i joint sono tracciati
        guard thumbTip.isTracked && indexTip.isTracked else { return }
        
        // Posizioni dei joint
        let thumbPos = thumbTip.anchorFromJointTransform.columns.3
        let indexPos = indexTip.anchorFromJointTransform.columns.3
        
        // Calcola distanza tra pollice e indice
        let distance = simd_distance(
            SIMD3<Float>(thumbPos.x, thumbPos.y, thumbPos.z),
            SIMD3<Float>(indexPos.x, indexPos.y, indexPos.z)
        )
        
        // Soglia per il pinch (3 cm)
        let pinchThreshold: Float = 0.03
        let isPinching = distance < pinchThreshold
        
        // Traccia quando inizia il pinch
        if !lastPinchState && isPinching {
            pinchStartTime = Date()
        }
        
        // Rileva quando il pinch viene rilasciato (era attivo, ora non lo è)
        if lastPinchState && !isPinching {
            // NUOVO: Controlla se dovremmo creare il marker
            if shouldCreateMarker() {
                // Calcola posizione del marker (punto medio tra pollice e indice)
                let markerLocalPos = (
                    SIMD3<Float>(thumbPos.x, thumbPos.y, thumbPos.z) +
                    SIMD3<Float>(indexPos.x, indexPos.y, indexPos.z)
                ) / 2
                
                // Trasforma in coordinate mondo
                let worldTransform = handAnchor.originFromAnchorTransform
                let markerWorldPos = worldTransform * SIMD4<Float>(markerLocalPos.x, markerLocalPos.y, markerLocalPos.z, 1)
                let finalPos = SIMD3<Float>(markerWorldPos.x, markerWorldPos.y, markerWorldPos.z)
                
                print("Pinch rilasciato! Posiziono marker a: \(finalPos)")
                
                await MainActor.run {
                    addMarker(at: finalPos)
                }
            } else {
                print("Pinch ignorato - interazione con UI o pinch troppo breve")
            }
            
            // Reset del timer
            pinchStartTime = nil
        }
        
        lastPinchState = isPinching
    }
    
    // NUOVO: Logica completa per decidere se creare il marker
    private func shouldCreateMarker() -> Bool {
        // 1. Controlla se c'è stata una recente interazione UI (ultimi 2 secondi)
        let timeSinceUIInteraction = Date().timeIntervalSince(lastUIInteractionTime)
        if timeSinceUIInteraction < 2.0 {
            print("❌ Non creo marker - recente interazione UI (\(timeSinceUIInteraction)s fa)")
            return false
        }
        
        // 2. Controlla il timing del pinch
        guard let startTime = pinchStartTime else {
            print("❌ Non creo marker - timing non valido")
            return false
        }
        
        let pinchDuration = Date().timeIntervalSince(startTime)
        
        // Se il pinch è durato meno di 0.3 secondi, probabilmente è un'interazione UI
        if pinchDuration < 0.3 {
            print("❌ Non creo marker - pinch troppo breve (\(pinchDuration)s)")
            return false
        }
        
        // 3. Controlla se il pinch è durato troppo a lungo (oltre 3 secondi = probabilmente non intenzionale)
        if pinchDuration > 3.0 {
            print("❌ Non creo marker - pinch troppo lungo (\(pinchDuration)s)")
            return false
        }
        
        print("✅ Creo marker - pinch valido (\(pinchDuration)s)")
        return true
    }
    
    // RIMOSSO: shouldCreateMarkerWithTiming() sostituito da shouldCreateMarker()
    
    // Aggiunge un marker nella posizione specificata
    private func addMarker(at position: SIMD3<Float>) {
        // Se abbiamo già 3 marker, rimuovi il più vecchio
        if appModel.markerManager.markers.count >= 3 {
            let oldMarker = appModel.markerManager.markers.removeFirst()
            oldMarker.removeFromParent()
        }
        
        // Crea nuovo marker
        let markerEntity = createMarkerEntity(at: position, index: appModel.markerManager.markers.count)
        appModel.markerManager.markers.append(markerEntity)
        
        // Aggiungi direttamente alla scena
        if let content = realityContent {
            content.add(markerEntity)
        }
        
        print("Marker aggiunto alla posizione: \(position). Totale marker: \(appModel.markerManager.markers.count)")
        
        // Se abbiamo 3 marker, crea il piano di taglio
        if appModel.markerManager.markers.count == 3 {
            createCuttingPlane()
        }
    }
    
    // Crea un'entità marker
    private func createMarkerEntity(at position: SIMD3<Float>, index: Int) -> Entity {
        let markerEntity = Entity()
        
        // Crea una sfera più piccola per il marker
        let sphereMesh = MeshResource.generateSphere(radius: 0.01) // Ridotto da 0.02 a 0.01
        
        // Tutti i marker sono blu
        let color = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.roughness = 0.3
        material.metallic = 0.7
        
        let modelEntity = ModelEntity(mesh: sphereMesh, materials: [material])
        markerEntity.addChild(modelEntity)
        markerEntity.position = position
        markerEntity.name = "Marker\(index)"
        
        return markerEntity
    }
    
    // Crea il piano di taglio
    private func createCuttingPlane() {
        guard appModel.markerManager.markers.count == 3 else {
            print("ERRORE: createCuttingPlane chiamato senza 3 marker")
            return
        }
        
        let pos1 = appModel.markerManager.markers[0].position
        let pos2 = appModel.markerManager.markers[1].position
        let pos3 = appModel.markerManager.markers[2].position
        
        print("Posizioni marker per piano: P1=\(pos1), P2=\(pos2), P3=\(pos3)")
        
        // Calcola normale del piano
        let v1 = pos2 - pos1
        let v2 = pos3 - pos1
        
        // Verifica che i vettori non siano paralleli
        let crossProduct = cross(v1, v2)
        let crossLength = simd_length(crossProduct)
        
        if crossLength < 0.001 {
            print("AVVERTIMENTO: I marker sono quasi collineari, piano potrebbe non essere visibile")
        }
        
        let normal = normalize(crossProduct)
        
        // Centro del piano
        let center = (pos1 + pos2 + pos3) / 3
        
        // Rimuovi piano precedente se esiste
        if let oldPlane = appModel.markerManager.cuttingPlane {
            oldPlane.removeFromParent()
            print("Piano precedente rimosso")
        }
        
        // Crea nuovo piano
        let planeEntity = Entity()
        let planeMesh = MeshResource.generatePlane(width: 1.0, depth: 1.0)
        
        var planeMaterial = SimpleMaterial()
        // Colore blu come specificato: NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.3)
        planeMaterial.color = .init(tint: UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.3))
        planeMaterial.roughness = 0.8
        
        let planeModel = ModelEntity(mesh: planeMesh, materials: [planeMaterial])
        planeEntity.addChild(planeModel)
        planeEntity.position = center
        
        // Orienta il piano
        let defaultNormal = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: defaultNormal, to: normal)
        planeEntity.orientation = rotation
        planeEntity.name = "CuttingPlane"
        
        // Salva il riferimento
        appModel.markerManager.cuttingPlane = planeEntity
        
        // Aggiungi FORZATAMENTE alla scena
        if let content = realityContent {
            content.add(planeEntity)
            print("Piano di taglio AGGIUNTO FORZATAMENTE alla scena")
        } else {
            print("ERRORE: realityContent è nil, impossibile aggiungere il piano")
        }
        
        print("Piano di taglio creato al centro: \(center) con normale: \(normal)")
        print("Lunghezza prodotto vettoriale: \(crossLength)")
    }
    
    // Aggiorna i marker nella scena
    private func updateMarkersInScene(content: RealityViewContent) {
        // Crea una lista degli entity da rimuovere per evitare problemi di concorrenza
        var entitiesToRemove: [Entity] = []
        
        for entity in content.entities {
            if entity.name.starts(with: "Marker") || entity.name == "CuttingPlane" {
                entitiesToRemove.append(entity)
            }
        }
        
        // Rimuovi gli entity
        for entity in entitiesToRemove {
            content.remove(entity)
        }
        
        // Aggiungi marker correnti (solo se non sono già nella scena)
        for marker in appModel.markerManager.markers {
            if marker.parent == nil {
                content.add(marker)
            }
        }
        
        // Aggiungi piano di taglio se esiste (solo se non è già nella scena)
        if let plane = appModel.markerManager.cuttingPlane, plane.parent == nil {
            content.add(plane)
        }
    }
    
    // Applica materiale olografico
    private func applyHolographicMaterial(to entity: Entity) {
        if let modelEntity = entity as? ModelEntity {
            var holographicMaterial = SimpleMaterial()
            holographicMaterial.color = .init(tint: UIColor.cyan.withAlphaComponent(0.7))
            holographicMaterial.roughness = 0.2
            holographicMaterial.metallic = 0.8
            
            modelEntity.model?.materials = [holographicMaterial]
        }
        
        for child in entity.children {
            applyHolographicMaterial(to: child)
        }
    }
    
    // Aggiunge illuminazione
    private func addLighting(to content: RealityViewContent) {
        let mainLight = Entity()
        mainLight.components[PointLightComponent.self] = PointLightComponent(
            color: .white,
            intensity: 1000,
            attenuationRadius: 10
        )
        mainLight.position = [0, 2, 0]
        content.add(mainLight)
        
        let accentLight = Entity()
        accentLight.components[PointLightComponent.self] = PointLightComponent(
            color: .cyan,
            intensity: 800,
            attenuationRadius: 5
        )
        accentLight.position = [1, 0, -1]
        content.add(accentLight)
        
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

// VERSIONE SEMPLIFICATA: Sistema di rilevamento UI per visionOS
extension ImmersiveView {
    // Funzione per simulare il rilevamento di interazioni UI
    private func markUIInteraction() {
        lastUIInteractionTime = Date()
        isLookingAtUI = true
        
        // Dopo 1 secondo, considera finita l'interazione UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLookingAtUI = false
        }
    }
    
    // Aggiungi questa funzione ai tuoi pulsanti e controlli UI
    private func onUIElementTapped() {
        markUIInteraction()
        // ... resto del codice del pulsante
    }
}
