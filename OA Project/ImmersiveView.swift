import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    // Stato per tenere traccia del modello caricato e eventuali errori
    @State private var isModelLoaded = false
    @State private var modelLoadingError: String? = nil
    // Aggiunta di stato per il debug
    @State private var debugMessages: [String] = []
    
    // Riferimento all'ancora del modello
    @State private var anchorEntityContainer: AnchorEntityContainer? = nil
    
    // Classe per mantenere un riferimento all'ancora
    class AnchorEntityContainer {
        let anchorEntity: AnchorEntity
        
        init(anchorEntity: AnchorEntity) {
            self.anchorEntity = anchorEntity
        }
    }
    
    // Funzione per aggiungere messaggi di debug
    private func addDebug(_ message: String) {
        print("DEBUG: \(message)")
        // Aggiorna la lista di messaggi di debug (limitandola a 20 messaggi)
        DispatchQueue.main.async {
            debugMessages.append(message)
            if debugMessages.count > 20 {
                debugMessages.removeFirst(debugMessages.count - 20)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Visualizzazione principale RealityKit
            RealityView { content in
                addDebug("Inizializzazione RealityView")
                
                // Aggiungi luce ambientale per illuminare il modello
                let ambientLight = Entity()
                let lightComponent = PointLightComponent(
                    color: .white,
                    intensity: 1000,
                    attenuationRadius: 10
                )
                ambientLight.components[PointLightComponent.self] = lightComponent
                ambientLight.position = SIMD3<Float>(0, 2, 0)
                content.add(ambientLight)
                addDebug("Luce ambientale aggiunta alla posizione \(ambientLight.position)")

                // Aggiungi una seconda luce per illuminare da un'altra angolazione
                let secondLight = Entity()
                let secondLightComponent = PointLightComponent(
                    color: .white,
                    intensity: 500,
                    attenuationRadius: 10
                )
                secondLight.components[PointLightComponent.self] = secondLightComponent
                secondLight.position = SIMD3<Float>(2, 0, 2)
                content.add(secondLight)
                addDebug("Seconda luce aggiunta alla posizione \(secondLight.position)")
                
                // Crea un'entità di ancoraggio per il modello che verrà caricato
                let anchorEntity = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.5, 0.5]))
                content.add(anchorEntity)
                
                // Salva il riferimento all'ancora in uno stato
                anchorEntityContainer = AnchorEntityContainer(anchorEntity: anchorEntity)
                
                addDebug("RealityView inizializzata e ancora creata")
            } update: { content in
                // Qui aggiorniamo la scena quando cambiano gli stati
                if let container = anchorEntityContainer, isModelLoaded {
                    addDebug("Aggiornamento RealityView in corso")
                    // Non facciamo nulla qui perché il modello sarà già stato aggiunto all'ancora
                }
            }
            .gesture(
                // Gestione rotazione del modello
                RotateGesture3D()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        addDebug("Rotazione in corso: \(value.rotation)")
                    }
            )
            .gesture(
                // Gestione spostamento del modello
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        addDebug("Trascinamento in corso: \(value.translation)")
                    }
            )
            .gesture(
                // Gestione scala del modello
                MagnifyGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        addDebug("Zoom in corso: \(value.magnification)")
                    }
            )
            
            // Overlay migliorato di informazioni di debug
            VStack(alignment: .leading) {
                // Debug info in alto
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(debugMessages.prefix(5), id: \.self) { message in
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(.top, 50)
                
                Spacer()
                
                // Stato del caricamento in basso
                if let error = modelLoadingError {
                    Text("Errore: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                } else if isModelLoaded {
                    Text("Modello caricato con successo")
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .onAppear {
                            addDebug("Overlay 'modello caricato' visualizzato")
                        }
                } else {
                    Text("Caricamento modello in corso...")
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                
                // Aggiungi un pulsante per provare a ricaricare il modello
                Button(action: {
                    addDebug("Tentativo di ricaricamento manuale")
                    loadBrainModel()
                }) {
                    Text("Ricarica modello")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom, 20)
            }
            .padding()
        }
        .onAppear {
            addDebug("ImmersiveView apparsa")
            // Stampa informazioni sul modello di cui stiamo tentando il caricamento
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let modelURL = documentsURL.appendingPathComponent("brain_model.usdz")
            
            addDebug("Verifica percorso del modello: \(modelURL.path)")
            addDebug("Il file esiste nei documenti: \(fileManager.fileExists(atPath: modelURL.path))")
            
            if let bundleURL = Bundle.main.url(forResource: "brain_model", withExtension: "usdz") {
                addDebug("Il file esiste nel bundle: \(bundleURL.path)")
            } else {
                addDebug("Il file NON esiste nel bundle")
                
                // Elenca risorse nel bundle per debug
                if let bundleResources = Bundle.main.urls(forResourcesWithExtension: "usdz", subdirectory: nil) {
                    addDebug("Modelli USDZ trovati nel bundle:")
                    for resource in bundleResources {
                        addDebug("- \(resource.lastPathComponent)")
                    }
                } else {
                    addDebug("Nessun modello USDZ trovato nel bundle")
                }
            }
            
            // Avvia il caricamento del modello
            loadBrainModel()
        }
    }
    
    // Funzione separata per caricare il modello del cervello
    private func loadBrainModel() {
        Task {
            do {
                addDebug("Iniziato processo di caricamento del modello")
                // Cerca di caricare il modello dalla libreria Documenti
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let modelURL = documentsURL.appendingPathComponent("brain_model.usdz")
                
                addDebug("Cerco il modello in: \(modelURL.path)")
                
                if fileManager.fileExists(atPath: modelURL.path) {
                    addDebug("File trovato nella cartella Documenti")
                    
                    let brainModelEntity = try ModelEntity.load(contentsOf: modelURL)
                    addDebug("Modello caricato in memoria")
                    
                    // Verifica che il modello abbia una mesh
                    if let modelComponent = brainModelEntity.components[ModelComponent.self] {
                        addDebug("Il modello ha una mesh valida")
                        
                        // Per debug aggiuntivo, verifichiamo i materiali
                        let materials = modelComponent.materials
                        if !materials.isEmpty {
                            addDebug("Il modello ha \(materials.count) materiali")
                        } else {
                            addDebug("ATTENZIONE - Il modello non ha materiali")
                        }
                    } else {
                        addDebug("ATTENZIONE - Il modello non ha una mesh valida!")
                    }
                    
                    // Configura il modello
                    brainModelEntity.name = "BrainModel"
                    
                    // Posiziona il modello di fronte all'utente
                    brainModelEntity.position = SIMD3<Float>(0, 0, -0.7)
                    addDebug("Modello posizionato a \(brainModelEntity.position)")
                    
                    // Scala il modello a una dimensione appropriata per la visualizzazione
                    brainModelEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
                    addDebug("Modello scalato a \(brainModelEntity.scale)")
                    
                    // Aggiungi componente di collisione per interazione
                    var collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.5, 0.5, 0.5])])
                    collisionComponent.mode = .trigger
                    brainModelEntity.components.set(collisionComponent)
                    addDebug("Componente di collisione aggiunto")
                    
                    // Aggiungi comportamento di interazione
                    brainModelEntity.components.set(InputTargetComponent())
                    addDebug("Componente di input target aggiunto")
                    
                    // Verifica se il modello ha un materiale
                    if let modelComponent = brainModelEntity.components[ModelComponent.self] {
                        let materials = modelComponent.materials
                        if !materials.isEmpty {
                            addDebug("Il modello ha \(materials.count) materiali")
                        } else {
                            addDebug("ATTENZIONE - Il modello non ha materiali. Aggiungo un materiale standard")
                            // Aggiungi un materiale di base se non ne ha
                            var simpleMaterial = SimpleMaterial(color: .white, isMetallic: false)
                            var updatedModelComponent = modelComponent
                            updatedModelComponent.materials = [simpleMaterial]
                            brainModelEntity.components[ModelComponent.self] = updatedModelComponent
                        }
                    }
                    
                    // Aggiungere il modello all'ancora
                    await MainActor.run {
                        if let container = anchorEntityContainer {
                            container.anchorEntity.addChild(brainModelEntity)
                            addDebug("Modello aggiunto all'anchor entity")
                            isModelLoaded = true
                        } else {
                            addDebug("ERRORE - Ancora non disponibile per aggiungere il modello")
                            modelLoadingError = "Ancora non disponibile"
                        }
                    }
                    
                    addDebug("Modello del cervello caricato con successo")
                } else {
                    addDebug("File brain_model.usdz non trovato nella cartella Documenti")
                    
                    // Elenca i file nella directory per debug
                    let documentsContents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                    addDebug("Contenuto della cartella Documenti:")
                    for file in documentsContents {
                        addDebug("- \(file.lastPathComponent)")
                    }
                    
                    // Come fallback, prova a caricare dal bundle
                    addDebug("Tentativo di caricamento dal bundle...")
                    if let bundleURL = Bundle.main.url(forResource: "brain_model", withExtension: "usdz") {
                        addDebug("Trovato file nel bundle: \(bundleURL.path)")
                        let brainModel = try ModelEntity.load(contentsOf: bundleURL)
                        brainModel.name = "BrainModel"  // Aggiungi nome per targeting
                        brainModel.position = SIMD3<Float>(0, 0, -0.7)
                        brainModel.scale = SIMD3<Float>(0.05, 0.05, 0.05)
                        
                        // Verifica la mesh e i materiali
                        if let modelComponent = brainModel.components[ModelComponent.self] {
                            addDebug("Il modello dal bundle ha una mesh valida")
                            
                            // Verifica materiali
                            let materials = modelComponent.materials
                            if !materials.isEmpty {
                                addDebug("Il modello dal bundle ha \(materials.count) materiali")
                            } else {
                                addDebug("ATTENZIONE - Il modello dal bundle non ha materiali")
                            }
                        }
                        
                        if let modelComponent = brainModel.components[ModelComponent.self] {
                            let modelMaterials = modelComponent.materials
                            if !modelMaterials.isEmpty {
                                addDebug("Il modello dal bundle ha \(modelMaterials.count) materiali")
                            } else {
                                addDebug("ATTENZIONE - Il modello dal bundle non ha materiali. Aggiungo un materiale standard")
                                var simpleMaterial = SimpleMaterial(color: .white, isMetallic: false)
                                var updatedModelComponent = modelComponent
                                updatedModelComponent.materials = [simpleMaterial]
                                brainModel.components[ModelComponent.self] = updatedModelComponent
                            }
                        }
                        
                        // Aggiungi componenti di interazione
                        var collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.5, 0.5, 0.5])])
                        collisionComponent.mode = .trigger
                        brainModel.components.set(collisionComponent)
                        brainModel.components.set(InputTargetComponent())
                        
                        // Aggiungere il modello all'ancora
                        await MainActor.run {
                            if let container = anchorEntityContainer {
                                container.anchorEntity.addChild(brainModel)
                                addDebug("Modello aggiunto all'anchor entity")
                                isModelLoaded = true
                            } else {
                                addDebug("ERRORE - Ancora non disponibile per aggiungere il modello")
                                modelLoadingError = "Ancora non disponibile"
                            }
                        }
                        
                        addDebug("Modello del cervello caricato dal bundle")
                    } else {
                        addDebug("ERRORE - Impossibile trovare brain_model.usdz nel bundle")
                        await MainActor.run {
                            modelLoadingError = "Modello non trovato nel bundle"
                        }
                    }
                }
            } catch {
                addDebug("ERRORE - Caricamento del modello fallito: \(error.localizedDescription)")
                addDebug("ERRORE dettagliato: \(error)")
                await MainActor.run {
                    modelLoadingError = error.localizedDescription
                }
            }
        }
    }

    // Funzione di utilità per generare uno skybox (per avere uno sfondo)
    private func generateSkybox() -> Entity {
        addDebug("Generazione skybox")
        let skybox = Entity()
        let material = UnlitMaterial(color: .gray)
        let sphere = ModelEntity(mesh: .generateSphere(radius: 10), materials: [material])
        sphere.components.set(InputTargetComponent(allowedInputTypes: []))
        skybox.addChild(sphere)
        addDebug("Skybox generato")
        return skybox
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
