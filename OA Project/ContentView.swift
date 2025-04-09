//
//  ContentView.swift
//  OA Project
//
//  Created by Alessandro Magnani on 21/03/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var showMessage = false

    var body: some View {
        VStack {
            Text("Brain Model Viewer")
                .font(.largeTitle)
                .padding(.bottom, 20)
            
            if let importMessage = importMessage, showMessage {
                Text(importMessage)
                    .foregroundColor(importMessage.contains("successo") ? .green : .red)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button("Importa Modello USDZ") {
                isImporting = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer()
            
            ToggleImmersiveSpaceButton()
                .padding(.vertical)
        }
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.usdz],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else {
                    importMessage = "Nessun file selezionato"
                    showMessage = true
                    return
                }
                
                // Inizia l'accesso sicuro al file
                if selectedFile.startAccessingSecurityScopedResource() {
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let destinationURL = documentsURL.appendingPathComponent("brain_model.usdz")
                    
                    // Rimuovi il file esistente se presente
                    try? FileManager.default.removeItem(at: destinationURL)
                    
                    // Copia il file
                    try FileManager.default.copyItem(at: selectedFile, to: destinationURL)
                    
                    importMessage = "Modello importato con successo!"
                    showMessage = true
                } else {
                    importMessage = "Impossibile accedere al file"
                    showMessage = true
                }
            } catch {
                importMessage = "Errore: \(error.localizedDescription)"
                showMessage = true
            }
        }
        .onChange(of: showMessage) { _, newValue in
            if newValue {
                // Nascondi il messaggio dopo 3 secondi
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    showMessage = false
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
