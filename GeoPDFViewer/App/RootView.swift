import SwiftUI

/// Entry screen: open the bundled sample GeoPDF or pick one from Files, then
/// hand the URL to `GeoPDFMapView`.
struct RootView: View {
    @State private var url: URL?
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("GeoPDF Viewer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPickerPresented = true
                        } label: {
                            Label("Open", systemImage: "folder")
                        }
                    }
                }
                .sheet(isPresented: $isPickerPresented) {
                    DocumentPicker { pickedURL in
                        url = pickedURL
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            GeoPDFMapView(url: url)
                .ignoresSafeArea(edges: .bottom)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Open a Geospatial PDF to see your location on it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            if let sample = Self.sampleURL {
                Button("Open Sample Map") { url = sample }
                    .buttonStyle(.borderedProminent)
            }
            Button("Choose from Files…") { isPickerPresented = true }
                .buttonStyle(.bordered)
        }
    }

    /// The GeoPDF bundled in the app (Resources/El Cajon Mountain Trail Map.pdf).
    static var sampleURL: URL? {
        Bundle.main.url(forResource: "El Cajon Mountain Trail Map", withExtension: "pdf")
    }
}

#Preview {
    RootView()
}
