import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import QuickLook
import SceneKit

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var showImporter = false
    @State private var loadingMessage = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isQuickLookPresented = false
    @State private var quickLookURL: URL? = nil
    @State private var selectedModelURL: URL? = nil
    
    var body: some View {
        ZStack {
            VStack {
                Text("3D Viewer")
                    .font(.largeTitle)
                    .padding()
                
                Button(action: {
                    showImporter = true
                }) {
                    Label("Import 3D Model", systemImage: "doc.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                if !loadingMessage.isEmpty {
                    Text(loadingMessage)
                        .padding()
                }
                
                // Mostra il modello se è stato caricato
                if let modelURL = selectedModelURL, modelURL.pathExtension.lowercased() == "scn" {
                    SceneView(
                        scene: {
                            do {
                                let scene = try SCNScene(url: modelURL, options: nil)
                                // Ruota la scena di 90 gradi sull'asse X per allinearla al piano verticale
                                scene.rootNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                                
                                // Posiziona la scena al centro della vista
                                let boundingBox = scene.rootNode.boundingBox
                                let centerY = (boundingBox.max.y + boundingBox.min.y) / 2
                                scene.rootNode.position = SCNVector3(0, -centerY, 0)
                                
                                return scene
                            } catch {
                                print("Errore nel caricamento della scena SCN: \(error)")
                                return SCNScene()
                            }
                        }(),
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .frame(height: 800)
                    .padding()
                }
                
                // Sezione dei controlli per lo spazio immersivo
                if appModel.immersiveSpaceState == .closed {
                    Button(action: {
                        // Prima di aprire lo spazio immersivo, carica il modello corrente
                        if let modelURL = selectedModelURL {
                            loadModelForImmersiveSpace(from: modelURL)
                            
                            // Ora apriamo lo spazio immersivo
                            Task {
                                let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                                if result == .opened {
                                    await MainActor.run {
                                        appModel.immersiveSpaceState = .open
                                    }
                                    print("Spazio immersivo aperto con successo")
                                } else {
                                    print("Errore nell'apertura dello spazio immersivo: \(result)")
                                    errorMessage = "Impossibile aprire lo spazio immersivo"
                                    showErrorAlert = true
                                }
                            }
                        }
                    }) {
                        Label("Immersive Space", systemImage: "cube")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    .disabled(selectedModelURL == nil)
                } else {
                    VStack(spacing: 10) {
                        // Informazioni sui marker
                        HStack {
                            Text("Markers: \(appModel.markerCount)/3")
                                .font(.headline)
                            
                            if appModel.isCuttingPlaneActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Cutting Plane Active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(8)
                        
                        // Istruzioni per l'utente
                        Text("Use pinch gesture to place markers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 20) {
                            // Pulsante per pulire i marker
                            Button(action: {
                                appModel.clearAllMarkers()
                            }) {
                                Label("Clear Markers", systemImage: "trash")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .disabled(appModel.markerCount == 0)
                            
                            // Pulsante per chiudere lo spazio immersivo
                            Button(action: {
                                Task {
                                    await dismissImmersiveSpace()
                                    await MainActor.run {
                                        appModel.immersiveSpaceState = .closed
                                    }
                                    print("Spazio immersivo chiuso con successo")
                                }
                            }) {
                                Label("Close", systemImage: "xmark.circle")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.usdz, .sceneKitScene],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let selectedURL = urls.first {
                    loadingMessage = "Loading model..."
                    loadModel(from: selectedURL)
                }
            case .failure(let error):
                errorMessage = "Import error: \(error.localizedDescription)"
                showErrorAlert = true
                print(errorMessage)
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage)
        }
        .quickLookPreview($quickLookURL, in: [quickLookURL].compactMap { $0 })
    }
    
    private func loadModel(from url: URL) {
        Task {
            do {
                // Inizia l'accesso sicuro all'URL
                guard url.startAccessingSecurityScopedResource() else {
                    print("Impossibile accedere alla risorsa con scope di sicurezza")
                    return
                }
                
                // Copia il file in una posizione all'interno del container dell'app
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                // Rimuovi eventuali file esistenti con lo stesso nome
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copia il file
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // Termina l'accesso sicuro
                url.stopAccessingSecurityScopedResource()
                
                print("File copiato con successo in: \(destinationURL)")
                
                await MainActor.run {
                    // Se è un file USDZ, usa QuickLook per visualizzarlo
                    if destinationURL.pathExtension.lowercased() == "usdz" {
                        self.quickLookURL = destinationURL
                        self.isQuickLookPresented = true
                        print("Visualizzazione USDZ con QuickLook: \(destinationURL.path)")
                    }
                    
                    // Salva il file per riferimento futuro
                    self.selectedModelURL = destinationURL
                    self.loadingMessage = ""
                }
            } catch {
                print("Errore: \(error)")
                await MainActor.run {
                    self.errorMessage = "Errore durante il caricamento: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    self.loadingMessage = ""
                }
            }
        }
    }
    
    // Metodo per caricare il modello per lo spazio immersivo
    private func loadModelForImmersiveSpace(from url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "scn" {
            Task {
                do {
                    // Carichiamo la scena SCN
                    let scnScene = try SCNScene(url: url, options: nil)
                    
                    // Creiamo un ModelEntity base
                    let rootModelEntity = ModelEntity()
                    
                    // Processiamo i nodi principali e otteniamo il bounding box
                    var minX: Float = .infinity
                    var minY: Float = .infinity
                    var minZ: Float = .infinity
                    var maxX: Float = -.infinity
                    var maxY: Float = -.infinity
                    var maxZ: Float = -.infinity
                    
                    processSceneNodes(scnScene.rootNode, parentEntity: rootModelEntity, minX: &minX, minY: &minY, minZ: &minZ, maxX: &maxX, maxY: &maxY, maxZ: &maxZ)
                    
                    // Calcola le dimensioni e il centro del modello
                    let center = SIMD3<Float>((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
                    let size = SIMD3<Float>(maxX - minX, maxY - minY, maxZ - minZ)
                    let maxDimension = max(max(size.x, size.y), size.z)
                    
                    // Scala il modello per visualizzarlo correttamente
                    let scale: Float = 0.5 / maxDimension  // Scala per adattare il modello a 0.5 metri
                    rootModelEntity.scale = SIMD3<Float>(repeating: scale)
                    
                    // Ruota il modello di 90 gradi sull'asse X per allinearlo correttamente
                    let rotation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
                    rootModelEntity.orientation = rotation
                    
                    // Spostiamo il modello verso l'alto per centrarlo
                    rootModelEntity.position = [0, 1.0, 0]
                    
                    await MainActor.run {
                        // Aggiorniamo il modello nell'AppModel
                        appModel.currentModel = rootModelEntity
                        appModel.modelScale = scale
                        appModel.modelCenter = center
                    }
                } catch {
                    print("Errore nella conversione SCN per lo spazio immersivo: \(error)")
                    errorMessage = "Errore nella conversione del modello: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        } else if fileExtension == "usdz" {
            Task {
                do {
                    let modelEntity = try await ModelEntity(contentsOf: url)
                    
                    // Calcola le dimensioni del modello
                    if let modelComponent = modelEntity.components[ModelComponent.self] {
                        let bounds = modelComponent.mesh.bounds
                        let maxDimension = max(max(bounds.extents.x, bounds.extents.y), bounds.extents.z)
                        let scale: Float = 0.5 / maxDimension  // Scala per adattare il modello a 0.5 metri
                        modelEntity.scale = SIMD3<Float>(repeating: scale)
                    }
                    
                    // Ruota il modello di 90 gradi sull'asse X per allinearlo correttamente
                    let rotation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
                    modelEntity.orientation = rotation
                    
                    // Spostiamo il modello verso l'alto per centrarlo
                    modelEntity.position = [0, 1.0, 0]
                    
                    await MainActor.run {
                        appModel.currentModel = modelEntity
                    }
                } catch {
                    print("Errore nel caricamento USDZ per lo spazio immersivo: \(error)")
                    errorMessage = "Errore nel caricamento del modello: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
    
    // Metodo per processare i nodi della scena e calcolare il bounding box
    private func processSceneNodes(_ node: SCNNode, parentEntity: Entity, minX: inout Float, minY: inout Float, minZ: inout Float, maxX: inout Float, maxY: inout Float, maxZ: inout Float) {
        // Applichiamo la trasformazione globale
        let position = node.worldPosition
        let positionFloat = SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
        
        // Aggiorniamo il bounding box
        minX = min(minX, positionFloat.x)
        minY = min(minY, positionFloat.y)
        minZ = min(minZ, positionFloat.z)
        maxX = max(maxX, positionFloat.x)
        maxY = max(maxY, positionFloat.y)
        maxZ = max(maxZ, positionFloat.z)
        
        // Per ogni nodo con geometria, creiamo un ModelEntity con un materiale traslucido
        if let geometry = node.geometry {
            // Creiamo un ModelEntity basato sul tipo di geometria
            var modelEntity: ModelEntity
            
            if let box = geometry as? SCNBox {
                let boxDimensions = SIMD3<Float>(Float(box.width), Float(box.height), Float(box.length))
                let boxMesh = MeshResource.generateBox(size: boxDimensions)
                let material = SimpleMaterial(color: .cyan, roughness: 0.2, isMetallic: false)
                modelEntity = ModelEntity(mesh: boxMesh, materials: [material])
            } else if let sphere = geometry as? SCNSphere {
                let sphereMesh = MeshResource.generateSphere(radius: Float(sphere.radius))
                let material = SimpleMaterial(color: .cyan, roughness: 0.2, isMetallic: false)
                modelEntity = ModelEntity(mesh: sphereMesh, materials: [material])
            } else {
                // Per altre geometrie, usiamo un box come segnaposto
                let boundingBox = node.boundingBox
                let minBound = boundingBox.min
                let maxBound = boundingBox.max
                let size = SIMD3<Float>(
                    Float(maxBound.x - minBound.x),
                    Float(maxBound.y - minBound.y),
                    Float(maxBound.z - minBound.z)
                )
                let length = sqrt(size.x * size.x + size.y * size.y + size.z * size.z)
                let boxMesh = MeshResource.generateBox(size: length > 0 ? size : [0.1, 0.1, 0.1])
                
                // Materiale olografico
                var material = SimpleMaterial()
                material.color = .init(tint: .cyan.withAlphaComponent(0.7))
                material.roughness = 0.2
                material.metallic = 0.8
                modelEntity = ModelEntity(mesh: boxMesh, materials: [material])
            }
            
            // Applichiamo la trasformazione
            modelEntity.position = positionFloat
            
            // Applichiamo la rotazione
            let rotation = node.worldOrientation
            modelEntity.orientation = simd_quatf(
                real: Float(rotation.w),
                imag: SIMD3<Float>(Float(rotation.x), Float(rotation.y), Float(rotation.z))
            )
            
            // Applichiamo la scala
            let worldTransform = node.worldTransform
            let scaleX = Float(sqrt(worldTransform.m11 * worldTransform.m11 + worldTransform.m12 * worldTransform.m12 + worldTransform.m13 * worldTransform.m13))
            let scaleY = Float(sqrt(worldTransform.m21 * worldTransform.m21 + worldTransform.m22 * worldTransform.m22 + worldTransform.m23 * worldTransform.m23))
            let scaleZ = Float(sqrt(worldTransform.m31 * worldTransform.m31 + worldTransform.m32 * worldTransform.m32 + worldTransform.m33 * worldTransform.m33))
            let scale = SIMD3<Float>(scaleX, scaleY, scaleZ)
            modelEntity.scale = scale
            
            // Aggiungiamo il modello al parent
            parentEntity.addChild(modelEntity)
        }
        
        // Processiamo i figli ricorsivamente
        for childNode in node.childNodes {
            processSceneNodes(childNode, parentEntity: parentEntity, minX: &minX, minY: &minY, minZ: &minZ, maxX: &maxX, maxY: &maxY, maxZ: &maxZ)
        }
    }
}

// Estensione per UTType per supportare i file .scn
extension UTType {
    static let sceneKitScene = UTType(filenameExtension: "scn")!
}
