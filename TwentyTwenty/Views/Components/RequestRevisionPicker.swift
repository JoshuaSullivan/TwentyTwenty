import SwiftUI

/// Picker for choosing which algorithm revision a Vision request should use.
///
/// The list is driven by the request type's `supportedRevisions`, which the OS filters at
/// runtime. That is what lets the app offer revisions introduced in a newer iOS than its
/// deployment target without any `@available` annotations: a revision the running system
/// doesn't know about simply never appears.
///
/// `Revision` enums are `Hashable` but expose no raw value or display name, so titles are
/// derived from the case name.
struct RequestRevisionPicker<Revision: Hashable>: View {
    /// Revisions the running OS supports for this request.
    let revisions: [Revision]

    /// The currently selected revision.
    @Binding var selection: Revision

    var body: some View {
        // A single supported revision offers the user no choice worth showing.
        if revisions.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Algorithm Revision")
                    .font(.subheadline)
                    .bold()

                Picker("Algorithm Revision", selection: $selection) {
                    ForEach(revisions, id: \.self) { revision in
                        Text(Self.title(for: revision)).tag(revision)
                    }
                }
                .pickerStyle(.segmented)

                Text("Newer revisions are trained on newer data. Apple doesn't document the differences between them.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Turns a case name such as `revision4` into `Revision 4`.
    private static func title(for revision: Revision) -> String {
        let raw = String(describing: revision)

        guard raw.hasPrefix("revision"),
              let number = Int(raw.dropFirst("revision".count))
        else { return raw }

        return "Revision \(number)"
    }
}
