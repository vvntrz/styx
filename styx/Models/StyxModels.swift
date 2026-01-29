import SwiftUI
import AVKit
import WebKit
import Combine


struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Type") }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        default: break
        }
    }
}

enum WidgetPosition: String, Codable {
    case topLeft = "topLeft"
    case topCenter = "topCenter"
    case topRight = "topRight"
    case centerLeft = "centerLeft"
    case center = "center"
    case centerRight = "centerRight"
    case bottomLeft = "bottomLeft"
    case bottomCenter = "bottomCenter"
    case bottomRight = "bottomRight"
    case custom // Uses exact X/Y coordinates
}

struct StyxProperty: Codable {
    let type: String // "color", "bool", "number", "text"
    var value: AnyCodable
    let label: String?
}

struct StyxConfig: Codable {
    let name: String
    let entry: String
    var width: CGFloat
    var height: CGFloat
    var doShow: Bool?
    
    var position: WidgetPosition?
    var x: CGFloat?
    var y: CGFloat?
    // using these as css vars
    var properties: [String: StyxProperty]?
    
    let allowTerminal: Bool?
}

struct SCWrapper: Codable {
    let url: String
    let conf: StyxConfig
}

struct ConfigS: Codable {
    let version: String
    var widgets: [SCWrapper]
    var presets: [StyxConfig]
}



class WidgetModel: ObservableObject, Identifiable {
    let id = UUID()
    let folderURL: URL
    @Published var config: StyxConfig
    
    init(folderURL: URL, config: StyxConfig) {
        self.folderURL = folderURL
        self.config = config
        self.config.doShow = true
    }
    
    func updateFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.config.position = .custom
        self.config.x = x
        self.config.y = y
        self.config.width = width
        self.config.height = height
    }
    
    func setPosition(_ pos: CGPoint) {
        self.config.position = .custom
        self.config.x = pos.x
        self.config.y = pos.y
    }
}
