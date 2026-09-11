import SwiftUI

/// Lists the bundled sample plus any GeoPDFs in the app's Documents folder
/// (drop files there via the Files app), and opens the chosen one on a map.
struct RootView: View {
    @State private var documents: [URL] = []
    @State private var isPickerPresented = false

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
                ToolbarItem(placement: .topBarTrailing) {
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
            .refreshable { reload() }
            .onAppear { reload() }
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
