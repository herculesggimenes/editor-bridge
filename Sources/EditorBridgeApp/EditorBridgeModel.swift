import AppKit
import Foundation

struct EditorBridgeConfig: Codable {
    var version = 1
    var launcher = Launcher()
    var associations = Associations()

    struct Launcher: Codable {
        var ghosttyApp = "Ghostty.app"
        var nvimBin = ""
        var tmuxDefaultSession = "main"
        var tmuxWindowName = "nvim"
    }

    struct Associations: Codable {
        var installDutiMappings = true
        var includeStaticBaseTypes = true
        var includeProgrammingPreset = true
        var includePlainText = false
        var includePublicData = false
        var customExtensions: [String] = []
        var customFilenames: [String] = []
        var excludedExtensions: [String] = []
        var excludedFilenames: [String] = []
        var extraContentTypes: [String] = []
    }
}

struct ProgrammableManifest: Codable {
    var source: String
    var sourceURL: String
    var generatedAt: String
    var extensions: [String]
    var filenames: [String]

    enum CodingKeys: String, CodingKey {
        case source
        case sourceURL = "source_url"
        case generatedAt = "generated_at"
        case extensions
        case filenames
    }
}

@MainActor
final class EditorBridgeModel: ObservableObject {
    @Published var config = EditorBridgeConfig()
    @Published var manifest = ProgrammableManifest(
        source: "Unavailable",
        sourceURL: "",
        generatedAt: "",
        extensions: [],
        filenames: []
    )
    @Published var statusMessage = ""
    @Published var isApplying = false

    private let decoder = PropertyListDecoder()
    private let encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return encoder
    }()

    init() {
        do {
            try ensureConfigExists()
            try load()
            try loadManifest()
            statusMessage = "Loaded configuration from \(Self.configURL.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func load() throws {
        let data = try Data(contentsOf: Self.configURL)
        config = try decoder.decode(EditorBridgeConfig.self, from: data)
    }

    func save() throws {
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(
            at: Self.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: Self.configURL, options: .atomic)
        statusMessage = "Saved configuration to \(Self.configURL.path)"
    }

    func revealConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.configURL])
    }

    func apply() {
        Task {
            isApplying = true
            do {
                try save()
                let output = try await Task.detached(priority: .userInitiated) {
                    try Self.runApplyHelper()
                }.value
                statusMessage = output.isEmpty ? "Applied configuration." : output
            } catch {
                statusMessage = error.localizedDescription
            }
            isApplying = false
        }
    }

    private func ensureConfigExists() throws {
        guard !FileManager.default.fileExists(atPath: Self.configURL.path) else {
            return
        }

        guard let defaultConfigURL = Bundle.module.url(forResource: "default-config", withExtension: "plist") else {
            throw CocoaError(.fileNoSuchFile)
        }

        try FileManager.default.createDirectory(
            at: Self.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try FileManager.default.copyItem(at: defaultConfigURL, to: Self.configURL)
    }

    private func loadManifest() throws {
        guard let manifestURL = Bundle.module.url(forResource: "default-programmable-files", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try Data(contentsOf: manifestURL)
        manifest = try JSONDecoder().decode(ProgrammableManifest.self, from: data)
    }

    nonisolated private static func runApplyHelper() throws -> String {
        let applyPath = ProcessInfo.processInfo.environment["EDITOR_BRIDGE_APPLY_BIN"]
            ?? NSString(string: "~/.local/bin/editor-bridge-apply").expandingTildeInPath
        let applyURL = URL(fileURLWithPath: applyPath)

        guard FileManager.default.isExecutableFile(atPath: applyURL.path) else {
            throw NSError(
                domain: "EditorBridge",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing apply helper at \(applyURL.path). Link `bin/editor-bridge-apply` into ~/.local/bin first."]
            )
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = applyURL
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let message = errorOutput.isEmpty ? output : errorOutput
        throw NSError(
            domain: "EditorBridge",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)]
        )
    }

    nonisolated static var configURL: URL {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["EDITOR_BRIDGE_CONFIG_PATH"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }

        let configHome = env["XDG_CONFIG_HOME"]
            ?? NSString(string: "~/.config").expandingTildeInPath
        return URL(fileURLWithPath: configHome)
            .appendingPathComponent("editor-bridge", isDirectory: true)
            .appendingPathComponent("config.plist")
    }
}
