# OA Project

**OA Project** è un'applicazione avanzata per la visualizzazione e l'analisi di modelli 3D in realtà mista, progettata per visionOS utilizzando Swift e SwiftUI. Supporta l'importazione di modelli USDZ e SCN, il posizionamento interattivo di marker e la generazione di piani di taglio per l'analisi geometrica.

---

## Overview

OA Project è uno strumento pensato per fornire un'esperienza immersiva di visualizzazione 3D, permettendo di analizzare modelli tridimensionali tramite marker interattivi e piani di taglio. Include funzionalità di hand tracking, gesture recognition avanzate e rendering olografico per un'esperienza di realtà mista completa.

---

## Features

### 3D Model Management

- **Import & Preview**: Caricamento di modelli 3D da file USDZ e SCN con anteprima integrata
- **Format Support**: Supporto nativo per formati SceneKit e Universal Scene Description
- **Real-time Conversion**: Conversione automatica SCN→RealityKit per l'ambiente immersivo

### Advanced Visualization

- **2D Preview**: Visualizzazione preliminare con controlli di rotazione e SceneView integrata
- **Immersive Experience**: Renderizzazione in realtà mista con materiali olografici
- **Holographic Rendering**: Rendering avanzato con materiali traslucidi e illuminazione dinamica

### Interactive Marker System

- **Hand Tracking Integration**: Rilevamento preciso dei gesti della mano tramite ARKit
- **Pinch Gesture Recognition**: Posizionamento marker con gesture di pinch calibrate
- **Smart UI Detection**: Filtraggio intelligente delle interazioni UI vs spazio 3D
- **Real-time Feedback**: Feedback visivo immediato per il posizionamento dei marker

### Cutting Plane Generation

- **Automatic Plane Calculation**: Generazione automatica di piani di taglio da 3 marker
- **Geometric Analysis**: Calcolo della normale del piano e validazione geometrica
- **Visual Representation**: Rendering del piano con materiali semi-trasparenti
- **Interactive Controls**: Controlli per la pulizia e la gestione dei marker

### Mixed Reality Features

- **Spatial Anchoring**: Ancoraggio spaziale dei modelli nell'ambiente reale
- **Hand Tracking**: Integrazione completa con il sistema di hand tracking di visionOS
- **Gesture Controls**: Controlli gestuali per rotazione e manipolazione dei modelli
- **Immersive Navigation**: Navigazione fluida tra modalità 2D e spazio immersivo

---

## Architecture

### Core Components

#### Core Module

- `AppModel`: Gestione centralizzata dello stato dell'applicazione con Observable pattern

#### UI Module

- `ContentView`: Interfaccia principale 2D con controlli di importazione e gestione
- `ImmersiveView`: Esperienza di realtà mista con RealityView e hand tracking

#### Service Module

- `MarkerManager`: Gestione avanzata dei marker con validazione geometrica

#### Utility Module

- `ModelLoader`: Caricamento e ottimizzazione dei modelli 3D

### Key Technologies

- **SwiftUI** – Framework dichiarativo per l'interfaccia utente
- **RealityKit** – Rendering e gestione di scene in realtà mista
- **ARKit** – Hand tracking e rilevamento spaziale
- **SceneKit** – Supporto per file SCN e preview 2D
- **SIMD** – Matematica vettoriale ad alte prestazioni per calcoli geometrici

---

## Getting Started

### Prerequisites

- Apple Vision Pro
- visionOS 2.0 o superiore
- Xcode 16.0 o superiore
- Swift 6.0 o superiore

### Installation

Clona il repository:

```bash
git clone https://github.com/alessandromagnani17/OA-Project.git
cd OA-Project
```

Configura il progetto Xcode:

1. Apri `OA Project.xcodeproj` in Xcode
2. Seleziona Apple Vision Pro come target
3. Verifica le capabilities per ARKit e hand tracking

### Build and Run

- Seleziona il simulatore Apple Vision Pro o dispositivo fisico
- Premi `Cmd+R` per compilare ed eseguire

---

## Usage

### Import 3D Models

1. Clicca su "Import 3D Model" nell'interfaccia principale
2. Seleziona un file `.usdz` o `.scn` dal dispositivo
3. Il modello verrà automaticamente caricato e ottimizzato

### Visualize Models

- Usa la **preview 2D** per ispezionare il modello prima dell'immersione
- Passa allo **spazio immersivo** per l'esperienza di realtà mista
- Utilizza gesture di drag per ruotare il modello nello spazio

### Place Interactive Markers

- Entra nello spazio immersivo e posiziona il modello
- Usa il **gesto di pinch** con la mano destra per posizionare marker
- Tieni il pinch per 0.3-3 secondi per una posizione accurata
- Visualizza il contatore dei marker nell'interfaccia

### Generate Cutting Planes

- Posiziona esattamente **3 marker** per attivare la generazione del piano
- Il piano di taglio apparirà automaticamente tra i marker
- Usa "Clear Markers" per resettare e ricominciare
- Il piano è visibile con materiali semi-trasparenti

### Advanced Controls

- **Gesture Controls**: Drag per rotazione, pinch per marker
- **UI Management**: Il sistema distingue automaticamente tra interazioni UI e spazio 3D
- **State Management**: Lo stato dell'applicazione è persistente tra sessioni immersive
