import Foundation
import RealityKit
import SceneKit
import SwiftUI

// Classe per centralizzare la logica di caricamento dei modelli
class ModelLoader {
    // Errori specifici del ModelLoader
    enum LoaderError: Error, LocalizedError {
        case fileAccessDenied
        case fileImportFailed(Error)
        case modelLoadingFailed(Error)
        case sceneConversionFailed(Error)
        case unsupportedFileFormat
        
        var errorDescription: String? {
            switch self {
            case .fileAccessDenied:
                return "File access denied"
            case .fileImportFailed(let error):
                return "Import failed: \(error.localizedDescription)"
            case .modelLoadingFailed(let error):
                return "Model loading failed: \(error.localizedDescription)"
            case .sceneConversionFailed(let error):
                return "Scene conversion failed: \(error.localizedDescription)"
            case .unsupportedFileFormat:
                return "Unsupported file format"
            }
        }
    }
    
    // Carica un modello e lo copia nel container dell'app
    static func loadModel(from url: URL) async throws -> URL {
        // Inizia l'accesso sicuro all'URL
        guard url.startAccessingSecurityScopedResource() else {
            throw LoaderError.fileAccessDenied
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Copia il file in una posizione all'interno del container dell'app
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            // Rimuovi eventuali file esistenti con lo stesso nome
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copia il file
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            print("File copiato con successo in: \(destinationURL)")
            return destinationURL
        } catch {
            throw LoaderError.fileImportFailed(error)
        }
    }
    
    // Prepara un ModelEntity per lo spazio immersivo
    static func prepareModelForImmersiveSpace(from url: URL) async throws -> (ModelEntity, SIMD3<Float>) {
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "scn" {
            // Per file SCN
            return try await convertSCNToModelEntity(from: url)
        } else if fileExtension == "usdz" {
            // Per file USDZ
            do {
                let modelEntity = try await ModelEntity(contentsOf: url)
                
                // Calcola le dimensioni del modello
                var center = SIMD3<Float>.zero
                var scale: Float = 1.0
                
                if let modelComponent = modelEntity.components[ModelComponent.self] {
                    let bounds = await modelComponent.mesh.bounds
                    let maxDimension = max(max(bounds.extents.x, bounds.extents.y), bounds.extents.z)
                    scale = 0.5 / maxDimension  // Scala per adattare il modello a 0.5 metri
                    modelEntity.scale = SIMD3<Float>(repeating: scale)
                    center = bounds.center
                }
                
                return (modelEntity, center)
            } catch {
                throw LoaderError.modelLoadingFailed(error)
            }
        } else {
            throw LoaderError.unsupportedFileFormat
        }
    }
    
    // Converte una scena SCN in un ModelEntity per RealityKit
    private static func convertSCNToModelEntity(from url: URL) async throws -> (ModelEntity, SIMD3<Float>) {
        do {
            // Carichiamo la scena SCN
            let scnScene = try SCNScene(url: url, options: nil)
            
            // Creiamo un ModelEntity base
            let rootModelEntity = ModelEntity()
            
            // Variabili per il bounding box
            var minX: Float = .infinity
            var minY: Float = .infinity
            var minZ: Float = .infinity
            var maxX: Float = -.infinity
            var maxY: Float = -.infinity
            var maxZ: Float = -.infinity
            
            // Processo ricorsivo per convertire nodi SCN in entità RealityKit
            processSceneNodes(scnScene.rootNode, parentEntity: rootModelEntity, minX: &minX, minY: &minY, minZ: &minZ, maxX: &maxX, maxY: &maxY, maxZ: &maxZ)
            
            // Calcola le dimensioni e il centro del modello
            let center = SIMD3<Float>((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
            let size = SIMD3<Float>(maxX - minX, maxY - minY, maxZ - minZ)
            let maxDimension = max(max(size.x, size.y), size.z)
            
            // Scala il modello per visualizzarlo correttamente
            let scale: Float = 0.5 / maxDimension  // Scala per adattare il modello a 0.5 metri
            rootModelEntity.scale = SIMD3<Float>(repeating: scale)
            
            return (rootModelEntity, center)
        } catch {
            throw LoaderError.sceneConversionFailed(error)
        }
    }
    
    // Converte ricorsivamente i nodi SCN in entità RealityKit
    private static func processSceneNodes(_ node: SCNNode, parentEntity: Entity, minX: inout Float, minY: inout Float, minZ: inout Float, maxX: inout Float, maxY: inout Float, maxZ: inout Float) {
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
        
        // Per ogni nodo con geometria, creiamo un ModelEntity
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
                // Calcolo manuale della lunghezza
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
            // Estrai la scala dalla matrice di trasformazione mondiale
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
