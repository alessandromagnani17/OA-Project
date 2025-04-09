import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import QuickLook // Aggiungi questa importazione

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showImporter = false
    @State private var isModelLoaded = false
    @State private var loadingMessage = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isQuickLookPresented = false
    @State private var quickLookURL: URL? = nil
    
    var body: some View {
        ZStack {
            VStack {
                Text("USDZ Viewer")
                    .font(.largeTitle)
                    .padding()
                
                Button(action: {
                    showImporter = true
                }) {
                    Label("Importa Modello USDZ", systemImage: "doc.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                if !loadingMessage.isEmpty {
                    Text(loadingMessage)
                        .padding()
                }
                
                if appModel.immersiveSpaceState == .closed {
                    Button(action: {
                        appModel.toggleImmersiveSpace()
                    }) {
                        Label("Spazio Immersivo", systemImage: "cube")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.usdz],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let selectedURL = urls.first {
                    loadingMessage = "Caricamento del modello..."
                    loadModel(from: selectedURL)
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
                
                // Set the QuickLook URL and present it
                await MainActor.run {
                    self.quickLookURL = destinationURL
                    self.isQuickLookPresented = true
                    self.loadingMessage = ""
                }
            } catch {
                print("Errore: \(error)")
            }
        }
    }
}

struct ModelViewer: View {
    var modelEntity: ModelEntity
    var appModel: AppModel
    @State private var url: URL?
    
    var body: some View {
        ZStack {
            if let url = url {
                // Vista 3D diretta dal file USDZ
                Model3D(url: url)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Caricamento modello...")
            }
            
            VStack {
                Spacer()
                HStack {
                    Button("Chiudi") {
                        NotificationCenter.default.post(name: Notification.Name.closeModelViewer, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
        }
        .onAppear {
            // Recupera l'URL del file USDZ dalla directory dei documenti
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                    let usdzFiles = files.filter { $0.pathExtension.lowercased() == "usdz" }
                    if let firstUsdzFile = usdzFiles.first {
                        self.url = firstUsdzFile
                        print("URL per la visualizzazione diretta: \(firstUsdzFile)")
                    } else {
                        print("Nessun file USDZ trovato nella directory documenti")
                    }
                } catch {
                    print("Errore nel leggere la directory: \(error)")
                }
            }
        }
    }
}
