import SwiftUI

/// Lists the bundled sample plus any GeoPDFs in the app's Documents folder
/// (drop files there via the Files app), and opens the chosen one on a map.
struct RootView: View {
    @State private var documents: [URL] = []
    @State private var isPickerPresented = false
    @State private var isScannerPresented = false
    @State private var isDownloading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let sample = Self.sampleURL {
                    Section("Sample") {
                        row(for: sample, deletable: false)
                    }
                }

                Section("My Files") {
                    if documents.isEmpty {
                        Text("No maps yet. Tap Open to import a GeoPDF, or add files to “GeoPDFViewer” in the Files app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(documents, id: \.self) { url in
                            row(for: url, deletable: true)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("GeoPDF Viewer")
            .navigationDestination(for: URL.self) { url in
                MapScreen(url: url)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isScannerPresented = true
                    } label: {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                    Button {
                        isPickerPresented = true
                    } label: {
                        Label("Open", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $isPickerPresented) {
                DocumentPicker { pickedURL in
                    importPicked(pickedURL)
                }
            }
            .sheet(isPresented: $isScannerPresented) {
                scannerSheet
            }
            .refreshable { reload() }
            .onAppear { reload() }
            .overlay { downloadOverlay }
            .alert("Import Failed",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { result in
                isScannerPresented = false
                handleScan(result)
            }
            .ignoresSafeArea()
            .navigationTitle("Scan a PDF QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isScannerPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private var downloadOverlay: some View {
        if isDownloading {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Downloading…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func row(for url: URL, deletable: Bool) -> some View {
        NavigationLink(value: url) {
            Label(url.deletingPathExtension().lastPathComponent, systemImage: "map")
        }
    }

    // MARK: - Actions

    private func reload() {
        documents = DocumentsStore.pdfURLs()
    }

    private func importPicked(_ url: URL) {
        // The picker returns a temporary copy; copy it into Documents so it
        // persists and shows up in the list (and in the Files app).
        try? DocumentsStore.importFile(from: url)
        reload()
    }

    private func handleScan(_ result: Result<String, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let scanned):
            do {
                let url = try PDFDownloader.url(from: scanned)
                downloadAndImport(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func downloadAndImport(_ url: URL) {
        isDownloading = true
        Task { @MainActor in
            defer { isDownloading = false }
            do {
                _ = try await PDFDownloader.downloadAndImport(from: url)
                reload()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            try? DocumentsStore.delete(documents[index])
        }
        reload()
    }

    /// The GeoPDF bundled in the app (Resources/El Cajon Mountain Trail Map.pdf).
    static var sampleURL: URL? {
        Bundle.main.url(forResource: "El Cajon Mountain Trail Map", withExtension: "pdf")
    }
}

/// Full-screen map for one document.
struct MapScreen: View {
    let url: URL

    var body: some View {
        GeoPDFMapView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(url.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RootView()
}
