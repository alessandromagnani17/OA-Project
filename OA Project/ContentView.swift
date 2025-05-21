import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import QuickLook
import SceneKit

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showImporter = false
    @State private var loadingState: LoadingState = .idle
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var selectedModelURL: URL? = nil
    // Aggiunte per supporto QuickLook USDZ
    @State private var isQuickLookPresented = false
    @State private var quickLookURL: URL? = nil
    
    // Enum per gestire lo stato di caricamento
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
        
        var message: String {
            switch self {
            case .idle: return ""
            case .loading: return "Caricamento del modello..."
            case .loaded: return ""
            case .error: return ""
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                // Header
                HeaderView()
                
                // Import button
                ImportButtonView(action: { showImporter = true })
                
                // Loading message
                if !loadingState.message.isEmpty {
                    Text(loadingState.message)
                        .padding()
                }
                
                // Model preview - Mostra il modello appropriato in base al tipo di file
                if let modelURL = selectedModelURL {
                    if modelURL.pathExtension.lowercased() == "usdz" {
                        // Per USDZ, usa Model3D
                        Model3D(url: modelURL)
                            .frame(height: 800)
                            .padding()
                    } else if modelURL.pathExtension.lowercased() == "scn" {
                        // Per SCN, usa SceneView
                        ModelContentView(modelURL: modelURL)
                            .frame(height: 800)
                            .padding()
                    }
                }
                
                // Immersive space controls
                ImmersiveControlView(
                    modelURL: selectedModelURL,
                    loadAction: { url in
                        Task { await loadModelForImmersiveSpace(from: url) }
                    }
                )
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
                    loadingState = .loading
                    Task { await loadModel(from: selectedURL) }
                }
            case .failure(let error):
                errorMessage = "Errore durante l'importazione: \(error.localizedDescription)"
                showErrorAlert = true
                print(errorMessage)
            }
        }
        .alert("Errore", isPresented: $showErrorAlert) {
            Button("OK") {
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage)
        }
        // Supporto QuickLook per anteprima USDZ
        .quickLookPreview($quickLookURL)
    }
    
    // Metodo semplificato per caricare il modello
    private func loadModel(from url: URL) async {
        do {
            let destinationURL = try await ModelLoader.loadModel(from: url)
            
            await MainActor.run {
                self.selectedModelURL = destinationURL
                self.loadingState = .loaded
                
                // Se è un file USDZ, imposta anche l'URL per QuickLook
                if destinationURL.pathExtension.lowercased() == "usdz" {
                    self.quickLookURL = destinationURL
                }
            }
        } catch let error as ModelLoader.LoaderError {
            await MainActor.run {
                self.errorMessage = error.errorDescription ?? "Errore sconosciuto"
                self.showErrorAlert = true
                self.loadingState = .error
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Errore durante il caricamento: \(error.localizedDescription)"
                self.showErrorAlert = true
                self.loadingState = .error
            }
        }
    }
    
    // Metodo per caricare il modello per lo spazio immersivo
    private func loadModelForImmersiveSpace(from url: URL) async {
        do {
            let (modelEntity, center) = try await ModelLoader.prepareModelForImmersiveSpace(from: url)
            
            await MainActor.run {
                appModel.currentModel = modelEntity
                appModel.modelCenter = center
            }
        } catch let error as ModelLoader.LoaderError {
            await MainActor.run {
                self.errorMessage = error.errorDescription ?? "Errore sconosciuto"
                self.showErrorAlert = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Errore nel caricamento del modello: \(error.localizedDescription)"
                self.showErrorAlert = true
            }
        }
    }
}

// Vista per visualizzare il modello 3D nella finestra principale
struct ModelContentView: View {
    let modelURL: URL
    
    var body: some View {
        if modelURL.pathExtension.lowercased() == "scn" {
            // Usa SceneView per file SCN
            SceneView(
                scene: {
                    do {
                        return try SCNScene(url: modelURL, options: nil)
                    } catch {
                        print("Errore nel caricamento della scena SCN: \(error)")
                        return SCNScene()
                    }
                }(),
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
        } else {
            // Usa Model3D per file USDZ
            Model3D(url: modelURL)
        }
    }
}

// Componenti modulari per la UI
struct HeaderView: View {
    var body: some View {
        Text("Visualizzatore 3D")
            .font(.largeTitle)
            .padding()
    }
}

struct ImportButtonView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("Importa Modello 3D", systemImage: "doc.badge.plus")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
}

struct ImmersiveControlView: View {
    @Environment(AppModel.self) private var appModel
    let modelURL: URL?
    let loadAction: (URL) -> Void
    
    var body: some View {
        if appModel.immersiveSpaceState == .closed {
            Button(action: {
                // Prima di aprire lo spazio immersivo, carica il modello corrente
                if let modelURL = modelURL {
                    loadAction(modelURL)
                }
                appModel.toggleImmersiveSpace()
            }) {
                Label("Spazio Immersivo", systemImage: "cube")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .disabled(modelURL == nil)
        } else {
            Button(action: {
                appModel.toggleImmersiveSpace()
            }) {
                Label("Chiudi Spazio Immersivo", systemImage: "xmark.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

// Estensione per UTType per supportare i file .scn
extension UTType {
    static let sceneKitScene = UTType(filenameExtension: "scn")!
}
