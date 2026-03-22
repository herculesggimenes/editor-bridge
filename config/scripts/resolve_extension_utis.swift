import Foundation
import UniformTypeIdentifiers

let data = FileHandle.standardInput.readDataToEndOfFile()
let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

struct Input: Decodable {
    let extensions: [String]
}

struct Output: Encodable {
    let resolvedUTIs: [String]

    enum CodingKeys: String, CodingKey {
        case resolvedUTIs = "resolved_utis"
    }
}

let input = try decoder.decode(Input.self, from: data)

var utis = Set<String>()

for rawExtension in input.extensions {
    let normalized = rawExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    guard !normalized.isEmpty else { continue }
    guard let type = UTType(filenameExtension: normalized) else { continue }
    let identifier = type.identifier
    if identifier.hasPrefix("dyn.") {
        continue
    }
    utis.insert(identifier)
}

let output = Output(resolvedUTIs: utis.sorted())
let encoded = try encoder.encode(output)
FileHandle.standardOutput.write(encoded)
