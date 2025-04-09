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
            
            // Verifica dimensione del file
            do {
                let attributes = try fileManager.attributesOfItem(atPath: modelURL.path)
                if let fileSize = attributes[.size] as? NSNumber {
                    addDebug("Dimensione del file: \(fileSize.intValue) bytes")
                }
            } catch {
                addDebug("Errore nel leggere gli attributi del file: \(error)")
            }
            
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
                
                // Verifica che il file sia leggibile
                do {
                    let data = try Data(contentsOf: modelURL)
                    addDebug("Dimensione del file USDZ: \(data.count) bytes")
                    if data.count < 1000 {
                        addDebug("AVVISO: File potrebbe essere troppo piccolo per essere un modello valido")
                    }
                } catch {
                    addDebug("Errore nel leggere i dati del file: \(error)")
                }
                
                addDebug("Cerco il modello in: \(modelURL.path)")
                
                if fileManager.fileExists(atPath: modelURL.path) {
                    addDebug("File trovato nella cartella Documenti")
                    
                    // Carica il modello come Entity (più generico)
                    var brainEntity: Entity
                    
                    do {
                        addDebug("Tentativo di caricamento come Entity")
                        brainEntity = try Entity.load(contentsOf: modelURL)
                        addDebug("Entity caricata in memoria")
                    } catch {
                        addDebug("Errore nel caricamento come Entity: \(error)")
                        
                        // Crea un semplice cubo come fallback
                        addDebug("Creazione di un modello di fallback")
                        let mesh = MeshResource.generateBox(size: 0.2)
                        let material = SimpleMaterial(color: .red, isMetallic: false)
                        brainEntity = ModelEntity(mesh: mesh, materials: [material])
                    }
                    
                    // Debug esteso sui componenti dell'entità
                    addDebug("Verifica componenti principali:")
                    if brainEntity.components[ModelComponent.self] != nil {
                        addDebug("- Ha ModelComponent")
                    } else {
                        addDebug("- NON ha ModelComponent")
                    }
                    if brainEntity.components[CollisionComponent.self] != nil {
                        addDebug("- Ha CollisionComponent")
                    } else {
                        addDebug("- NON ha CollisionComponent")
                    }
                    if brainEntity.components[InputTargetComponent.self] != nil {
                        addDebug("- Ha InputTargetComponent")
                    } else {
                        addDebug("- NON ha InputTargetComponent")
                    }
                    if brainEntity.components[PointLightComponent.self] != nil {
                        addDebug("- Ha PointLightComponent")
                    } else {
                        addDebug("- NON ha PointLightComponent")
                    }
                    
                    // Verifica che il modello abbia una mesh tramite il componente ModelComponent
                    if let modelComponent = brainEntity.components[ModelComponent.self] {
                        addDebug("Il modello ha una mesh valida")
                        
                        // Per debug aggiuntivo, verifichiamo i materiali
                        let materials = modelComponent.materials
                        if !materials.isEmpty {
                            addDebug("Il modello ha \(materials.count) materiali")
                            // Esamina il primo materiale
                            addDebug("Primo materiale tipo: \(type(of: materials[0]))")
                        } else {
                            addDebug("ATTENZIONE - Il modello non ha materiali")
                            
                            // Se non ci sono materiali, aggiungiamone uno di default
                            if var modelComp = brainEntity.components[ModelComponent.self] as? ModelComponent {
                                let simpleMaterial = SimpleMaterial(color: .white, isMetallic: false)
                                modelComp.materials = [simpleMaterial]
                                brainEntity.components[ModelComponent.self] = modelComp
                                addDebug("Aggiunto materiale di default")
                            }
                        }
                    } else {
                        addDebug("ATTENZIONE - Il modello non ha una mesh valida!")
                        
                        // Se l'entità non è un ModelEntity, crea uno di fallback
                        if !(brainEntity is ModelEntity) {
                            addDebug("L'entità caricata non è un ModelEntity, creazione fallback")
                            let mesh = MeshResource.generateBox(size: 0.2)
                            let material = SimpleMaterial(color: .red, isMetallic: false)
                            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
                            
                            // Trasferisci attributi dall'entità originale
                            modelEntity.name = brainEntity.name
                            modelEntity.transform = brainEntity.transform
                            
                            // Sostituisci con il modello di fallback
                            brainEntity = modelEntity
                            addDebug("Sostituito con ModelEntity di fallback")
                        }
                    }
                    
                    // Configura il modello
                    brainEntity.name = "BrainModel"
                    
                    // Posiziona il modello di fronte all'utente
                    brainEntity.position = SIMD3<Float>(0, 0, -0.7)
                    addDebug("Modello posizionato a \(brainEntity.position)")
                    
                    // Scala il modello a una dimensione appropriata per la visualizzazione
                    brainEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
                    addDebug("Modello scalato a \(brainEntity.scale)")
                    
                    // Se l'entità è un ModelEntity, aggiungi componenti di interazione
                    if let modelEntity = brainEntity as? ModelEntity {
                        // Aggiungi componente di collisione per interazione
                        var collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.5, 0.5, 0.5])])
                        collisionComponent.mode = .trigger
                        modelEntity.components.set(collisionComponent)
                        addDebug("Componente di collisione aggiunto")
                        
                        // Aggiungi comportamento di interazione
                        modelEntity.components.set(InputTargetComponent())
                        addDebug("Componente di input target aggiunto")
                    } else {
                        addDebug("NOTA: Non è stato possibile aggiungere componenti di collisione e interazione (l'entità non è un ModelEntity)")
                    }
                    
                    // Aggiungere il modello all'ancora
                    await MainActor.run {
                        if let container = anchorEntityContainer {
                            container.anchorEntity.addChild(brainEntity)
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
                        
                        // Carica il modello come Entity (più generico)
                        var brainEntity: Entity
                        
                        do {
                            addDebug("Tentativo di caricamento dal bundle come Entity")
                            brainEntity = try Entity.load(contentsOf: bundleURL)
                            addDebug("Entity dal bundle caricata in memoria")
                        } catch {
                            addDebug("Errore nel caricamento come Entity dal bundle: \(error)")
                            
                            // Crea un semplice cubo come fallback
                            addDebug("Creazione di un modello di fallback")
                            let mesh = MeshResource.generateBox(size: 0.2)
                            let material = SimpleMaterial(color: .red, isMetallic: false)
                            brainEntity = ModelEntity(mesh: mesh, materials: [material])
                        }
                        
                        // Debug esteso sui componenti dell'entità
                        addDebug("Verifica componenti principali dell'entità dal bundle:")
                        if brainEntity.components[ModelComponent.self] != nil {
                            addDebug("- Ha ModelComponent")
                        } else {
                            addDebug("- NON ha ModelComponent")
                        }
                        if brainEntity.components[CollisionComponent.self] != nil {
                            addDebug("- Ha CollisionComponent")
                        } else {
                            addDebug("- NON ha CollisionComponent")
                        }
                        if brainEntity.components[InputTargetComponent.self] != nil {
                            addDebug("- Ha InputTargetComponent")
                        } else {
                            addDebug("- NON ha InputTargetComponent")
                        }
                        if brainEntity.components[PointLightComponent.self] != nil {
                            addDebug("- Ha PointLightComponent")
                        } else {
                            addDebug("- NON ha PointLightComponent")
                        }
                        
                        // Verifica che il modello abbia una mesh
                        if let modelComponent = brainEntity.components[ModelComponent.self] {
                            addDebug("Il modello dal bundle ha una mesh valida")
                            
                            // Verifica materiali
                            let materials = modelComponent.materials
                            if !materials.isEmpty {
                                addDebug("Il modello dal bundle ha \(materials.count) materiali")
                                // Esamina il primo materiale
                                addDebug("Primo materiale tipo: \(type(of: materials[0]))")
                            } else {
                                addDebug("ATTENZIONE - Il modello dal bundle non ha materiali")
                                
                                // Se non ci sono materiali, aggiungiamone uno di default
                                if var modelComp = brainEntity.components[ModelComponent.self] as? ModelComponent {
                                    let simpleMaterial = SimpleMaterial(color: .white, isMetallic: false)
                                    modelComp.materials = [simpleMaterial]
                                    brainEntity.components[ModelComponent.self] = modelComp
                                    addDebug("Aggiunto materiale di default al modello dal bundle")
                                }
                            }
                        } else {
                            addDebug("ATTENZIONE - Il modello dal bundle non ha una mesh valida!")
                            
                            // Se l'entità non è un ModelEntity, crea uno di fallback
                            if !(brainEntity is ModelEntity) {
                                addDebug("L'entità dal bundle non è un ModelEntity, creazione fallback")
                                let mesh = MeshResource.generateBox(size: 0.2)
                                let material = SimpleMaterial(color: .red, isMetallic: false)
                                let modelEntity = ModelEntity(mesh: mesh, materials: [material])
                                
                                // Trasferisci attributi dall'entità originale
                                modelEntity.name = brainEntity.name
                                modelEntity.transform = brainEntity.transform
                                
                                // Sostituisci con il modello di fallback
                                brainEntity = modelEntity
                                addDebug("Sostituito con ModelEntity di fallback per il modello dal bundle")
                            }
                        }
                        
                        // Configura il modello
                        brainEntity.name = "BrainModel"
                        brainEntity.position = SIMD3<Float>(0, 0, -0.7)
                        brainEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
                        
                        // Se l'entità è un ModelEntity, aggiungi componenti di interazione
                        if let modelEntity = brainEntity as? ModelEntity {
                            // Aggiungi componente di collisione per interazione
                            var collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.5, 0.5, 0.5])])
                            collisionComponent.mode = .trigger
                            modelEntity.components.set(collisionComponent)
                            
                            // Aggiungi comportamento di interazione
                            modelEntity.components.set(InputTargetComponent())
                            addDebug("Componenti di collisione e input target aggiunti al modello dal bundle")
                        } else {
                            addDebug("NOTA: Non è stato possibile aggiungere componenti di collisione e interazione al modello dal bundle (l'entità non è un ModelEntity)")
                        }
                        
                        // Aggiungere il modello all'ancora
                        await MainActor.run {
                            if let container = anchorEntityContainer {
                                container.anchorEntity.addChild(brainEntity)
                                addDebug("Modello dal bundle aggiunto all'anchor entity")
                                isModelLoaded = true
                            } else {
                                addDebug("ERRORE - Ancora non disponibile per aggiungere il modello dal bundle")
                                modelLoadingError = "Ancora non disponibile"
                            }
                        }
                        
                        addDebug("Modello del cervello caricato dal bundle")
                    } else {
                        addDebug("ERRORE - Impossibile trovare brain_model.usdz nel bundle")
                        
                        // Crea un modello di fallback (cubo rosso)
                        addDebug("Creazione di un modello di fallback come ultimo tentativo")
                        let mesh = MeshResource.generateBox(size: 0.2)
                        let material = SimpleMaterial(color: .red, isMetallic: false)
                        let fallbackModel = ModelEntity(mesh: mesh, materials: [material])
                        
                        fallbackModel.name = "FallbackModel"
                        fallbackModel.position = SIMD3<Float>(0, 0, -0.7)
                        
                        // Aggiungi componente di collisione per interazione
                        var collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.2, 0.2, 0.2])])
                        collisionComponent.mode = .trigger
                        fallbackModel.components.set(collisionComponent)
                        fallbackModel.components.set(InputTargetComponent())
                        
                        await MainActor.run {
                            if let container = anchorEntityContainer {
                                container.anchorEntity.addChild(fallbackModel)
                                addDebug("Modello di fallback aggiunto all'anchor entity")
                                isModelLoaded = true
                                modelLoadingError = "Utilizzato modello di fallback (cubo rosso)"
                            } else {
                                addDebug("ERRORE - Ancora non disponibile per aggiungere il modello di fallback")
                                modelLoadingError = "Ancora non disponibile, fallback fallito"
                            }
                        }
                    }
                }
            } catch {
                addDebug("ERRORE - Caricamento del modello fallito: \(error.localizedDescription)")
                addDebug("ERRORE dettagliato: \(error)")
                
                // Crea un modello di fallback (cubo rosso) in caso di errore
                addDebug("Tentativo di creazione modello di fallback dopo errore")
                let mesh = MeshResource.generateBox(size: 0.2)
                let material = SimpleMaterial(color: .red, isMetallic: false)
                let fallbackModel = ModelEntity(mesh: mesh, materials: [material])
                
                fallbackModel.name = "ErrorFallbackModel"
                fallbackModel.position = SIMD3<Float>(0, 0, -0.7)
                
                // Aggiungi componente di collisione per interazione
                var collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.2, 0.2, 0.2])])
                collisionComponent.mode = .trigger
                fallbackModel.components.set(collisionComponent)
                fallbackModel.components.set(InputTargetComponent())
                
                await MainActor.run {
                    if let container = anchorEntityContainer {
                        container.anchorEntity.addChild(fallbackModel)
                        addDebug("Modello di fallback dopo errore aggiunto all'anchor entity")
                        isModelLoaded = true
                        modelLoadingError = "Errore: \(error.localizedDescription)\nUtilizzato fallback"
                    } else {
                        modelLoadingError = error.localizedDescription
                    }
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
