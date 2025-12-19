import SwiftUI

/// Preview and edit detected URLs before importing
struct ImportPreviewView: View {
    let urls: [String]
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @State private var editableURLs: [EditableURL]
    @State private var showingDeleteConfirmation = false
    @State private var urlToDelete: EditableURL?

    init(urls: [String], onConfirm: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
        self.urls = urls
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _editableURLs = State(initialValue: urls.map { EditableURL(url: $0) })
    }

    var validURLs: [String] {
        editableURLs.compactMap { $0.isValid ? $0.url : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: HeirloomSpacing.sm) {
                Text("Review URLs")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                HStack(spacing: HeirloomSpacing.sm) {
                    Label("\(validURLs.count)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("recipes ready to import")
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .font(HeirloomFonts.callout)
            }
            .padding(HeirloomSpacing.lg)
            .background(Color.white)

            Divider()

            // URL List
            List {
                ForEach($editableURLs) { $editableURL in
                    URLRowView(
                        editableURL: $editableURL,
                        onDelete: {
                            urlToDelete = editableURL
                            showingDeleteConfirmation = true
                        }
                    )
                    .listRowInsets(EdgeInsets(
                        top: HeirloomSpacing.sm,
                        leading: HeirloomSpacing.md,
                        bottom: HeirloomSpacing.sm,
                        trailing: HeirloomSpacing.md
                    ))
                }
            }
            .listStyle(.plain)

            // Bottom Actions
            VStack(spacing: HeirloomSpacing.md) {
                Button {
                    onConfirm(validURLs)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import \(validURLs.count) Recipes")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(validURLs.isEmpty ? HeirloomColors.warmGray : HeirloomColors.tomato)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(validURLs.isEmpty)

                Button("Cancel") {
                    onCancel()
                }
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(HeirloomSpacing.lg)
            .background(Color.white)
        }
        .confirmationDialog(
            "Delete URL",
            isPresented: $showingDeleteConfirmation,
            presenting: urlToDelete
        ) { url in
            Button("Delete", role: .destructive) {
                editableURLs.removeAll { $0.id == url.id }
            }
        } message: { url in
            Text("Remove this URL from the import?")
        }
    }
}

// MARK: - URL Row

struct URLRowView: View {
    @Binding var editableURL: EditableURL
    let onDelete: () -> Void

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            HStack {
                // Status Icon
                Image(systemName: editableURL.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(editableURL.isValid ? HeirloomColors.tomato : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    if isEditing {
                        TextField("URL", text: $editableURL.url)
                            .font(HeirloomFonts.body)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    } else {
                        Text(editableURL.displayURL)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .lineLimit(2)

                        if let domain = URLNormalizer.extractDomain(editableURL.url) {
                            Text(domain)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(isEditing ? "Done" : "Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .font(.title3)
                }
            }

            if !editableURL.isValid {
                Text("Invalid URL - will be skipped")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.orange)
            }
        }
        .padding(HeirloomSpacing.sm)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Models

struct EditableURL: Identifiable, Equatable {
    let id = UUID()
    var url: String

    var isValid: Bool {
        URLNormalizer.isValidForImport(url)
    }

    var displayURL: String {
        url.count > 60 ? url.prefix(57) + "..." : url
    }
}

// MARK: - Preview

#Preview {
    ImportPreviewView(
        urls: [
            "https://cooking.nytimes.com/recipes/1024647-chocolate-chip-cookies",
            "https://www.allrecipes.com/recipe/25037/best-chocolate-chip-cookies/",
            "https://www.bonappetit.com/recipe/bas-best-chocolate-chip-cookies",
            "invalid url"
        ],
        onConfirm: { urls in
            print("Confirmed: \(urls.count) URLs")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
