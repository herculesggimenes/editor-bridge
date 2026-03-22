import SwiftUI

struct ContentView: View {
    @ObservedObject var model: EditorBridgeModel

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }

            associationsTab
                .tabItem {
                    Label("Associations", systemImage: "doc.text")
                }
        }
        .padding(24)
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryCard

            Form {
                Section("Launch Runtime") {
                    TextField("Ghostty.app", text: $model.config.launcher.ghosttyApp)
                    TextField("Optional nvim path", text: $model.config.launcher.nvimBin)
                    TextField("tmux default session", text: $model.config.launcher.tmuxDefaultSession)
                    TextField("tmux window name", text: $model.config.launcher.tmuxWindowName)
                }

                Section("Apply") {
                    Toggle("Install duti mappings when applying", isOn: $model.config.associations.installDutiMappings)
                    HStack {
                        Button("Save") {
                            do {
                                try model.save()
                            } catch {
                                model.statusMessage = error.localizedDescription
                            }
                        }

                        Button(model.isApplying ? "Applying…" : "Save and Apply") {
                            model.apply()
                        }
                        .disabled(model.isApplying)

                        Button("Reveal Config") {
                            model.revealConfig()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var associationsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Preset") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Include broad programmable-file preset", isOn: $model.config.associations.includeProgrammingPreset)
                        Toggle("Include static base UTIs", isOn: $model.config.associations.includeStaticBaseTypes)
                        Toggle("Include public.plain-text", isOn: $model.config.associations.includePlainText)
                        Toggle("Include public.data fallback", isOn: $model.config.associations.includePublicData)

                        Divider()

                        Text("Default preset source: \(model.manifest.source)")
                        Text("Extensions: \(model.manifest.extensions.count)")
                        Text("Exact filenames: \(model.manifest.filenames.count)")
                        if !model.manifest.generatedAt.isEmpty {
                            Text("Generated: \(model.manifest.generatedAt)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                EditableStringListSection(
                    title: "Custom Extensions",
                    description: "Extensions can be entered with or without a leading dot.",
                    items: $model.config.associations.customExtensions,
                    placeholder: ".tfvars"
                )

                EditableStringListSection(
                    title: "Custom Filenames",
                    description: "Exact filenames such as `.foo` or `Brewfile.local`.",
                    items: $model.config.associations.customFilenames,
                    placeholder: ".env.staging"
                )

                EditableStringListSection(
                    title: "Excluded Extensions",
                    description: "Remove extensions from the preset without disabling it.",
                    items: $model.config.associations.excludedExtensions,
                    placeholder: ".txt"
                )

                EditableStringListSection(
                    title: "Excluded Filenames",
                    description: "Remove exact filenames from the preset.",
                    items: $model.config.associations.excludedFilenames,
                    placeholder: "Dockerfile"
                )

                EditableStringListSection(
                    title: "Extra Content Types",
                    description: "Additional UTIs to claim and map with duti.",
                    items: $model.config.associations.extraContentTypes,
                    placeholder: "public.python-script"
                )
            }
        }
    }

    private var summaryCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Editor Bridge")
                    .font(.title2.weight(.semibold))
                Text("Configure how Finder, Git, Codex, and Zed-compatible callers route files into Ghostty, tmux, and Neovim.")
                    .foregroundStyle(.secondary)
                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EditableStringListSection: View {
    let title: String
    let description: String
    @Binding var items: [String]
    let placeholder: String

    @State private var draft = ""

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 10) {
                Text(description)
                    .foregroundStyle(.secondary)

                ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField(placeholder, text: binding(for: index))
                        Button {
                            items.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    TextField(placeholder, text: $draft)
                    Button("Add") {
                        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        items.append(value)
                        draft = ""
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { items[index] = $0 }
        )
    }
}
