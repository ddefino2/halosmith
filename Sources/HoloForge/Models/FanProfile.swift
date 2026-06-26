import Foundation

enum FanProfile: String, CaseIterable, Identifiable {
    case fMini11
    case large42BIN

    var id: Self { self }

    var name: String {
        switch self {
        case .fMini11: "F-mini 11"
        case .large42BIN: "Large fan (42 cm)"
        }
    }

    var detail: String {
        switch self {
        case .fMini11: "48-LED type-7 BIN · 1:1 source"
        case .large42BIN: "224-LED polar BIN · 1:1 source"
        }
    }

    var outputExtension: String {
        switch self {
        case .fMini11: "bin"
        case .large42BIN: "bin"
        }
    }

    var isExportAvailable: Bool { true }

    var outputSizeLabel: String {
        switch self {
        case .fMini11: "48-LED polar BIN output"
        case .large42BIN: "224-LED polar BIN output"
        }
    }
}
