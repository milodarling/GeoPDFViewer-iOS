import SwiftUI

/// Browse saved sessions. Tap one for its route and stats; swipe to delete.
struct SessionsListView: View {
    @State private var summaries: [SessionSummary] = []

    var body: some View {
        List {
            if summaries.isEmpty {
                Text("No saved sessions yet. Record a track and tap Finish to save it here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summaries) { summary in
                    NavigationLink(value: summary) {
                        row(summary)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Sessions")
        .onAppear(perform: reload)
        .refreshable { reload() }
    }

    private func row(_ summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title).font(.headline)
            Text("\(StatFormatting.distance(summary.distance)) · \(StatFormatting.duration(summary.duration)) · \(StatFormatting.elevation(summary.elevationGain)) ↑")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func reload() {
        summaries = SessionLibrary.shared.summaries()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            SessionLibrary.shared.delete(summaries[index].id)
        }
        reload()
    }
}
