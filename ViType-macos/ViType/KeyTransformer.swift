//
//  KeyTransformer.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import Foundation

struct KeyTransformAction: Equatable {
    let deleteCount: Int
    let text: String
}

enum InputMethod: Int32 {
    case telex = 0
    case vni = 1
}

enum OutputEncoding: Int32 {
    case unicode = 0
    case compositeUnicode = 1
}

enum TonePlacement: Int32 {
    case orthographic = 0
    case nucleusOnly = 1
}

final class KeyTransformer {
    private var engine: OpaquePointer?

    var inputMethod: InputMethod = .telex {
        didSet {
            guard inputMethod != oldValue else { return }
            if let engine {
                vitype_engine_set_input_method(engine, inputMethod.rawValue)
                // Engine keeps an internal buffer; switching method should clear it to avoid mixed parsing.
                vitype_engine_reset(engine)
            }
        }
    }

    var autoFixTone: Bool = true {
        didSet {
            if let engine {
                vitype_engine_set_auto_fix_tone(engine, autoFixTone)
            }
        }
    }

    var freeTonePlacement: Bool = false {
        didSet {
            if let engine {
                vitype_engine_set_free_tone_placement(engine, freeTonePlacement)
            }
        }
    }

    var outputEncoding: OutputEncoding = .unicode {
        didSet {
            if let engine {
                vitype_engine_set_output_encoding(engine, outputEncoding.rawValue)
            }
        }
    }

    var tonePlacement: TonePlacement = .orthographic {
        didSet {
            guard tonePlacement != oldValue else { return }
            if let engine {
                vitype_engine_set_tone_placement(engine, tonePlacement.rawValue)
                // Changing tone placement rules should clear the buffer to avoid mixed behavior mid-word.
                vitype_engine_reset(engine)
            }
        }
    }

    init() {
        engine = vitype_engine_new()
        if let engine {
            vitype_engine_set_input_method(engine, inputMethod.rawValue)
            vitype_engine_set_auto_fix_tone(engine, autoFixTone)
            vitype_engine_set_free_tone_placement(engine, freeTonePlacement)
            vitype_engine_set_output_encoding(engine, outputEncoding.rawValue)
            vitype_engine_set_tone_placement(engine, tonePlacement.rawValue)
        }
    }

    deinit {
        if let engine {
            vitype_engine_free(engine)
        }
    }

    func process(input: String) -> KeyTransformAction? {
        guard let engine else { return nil }
        return input.withCString { cString in
            let result = vitype_engine_process(engine, cString)
            guard result.has_action else { return nil }
            guard let textPtr = result.text else {
                return KeyTransformAction(deleteCount: Int(result.delete_count), text: "")
            }
            let text = String(cString: textPtr)
            vitype_engine_free_string(textPtr)
            return KeyTransformAction(deleteCount: Int(result.delete_count), text: text)
        }
    }

    func reset() {
        if let engine {
            vitype_engine_reset(engine)
        }
    }

    func deleteLastCharacter() {
        if let engine {
            vitype_engine_delete_last_character(engine)
        }
    }

    func currentWordLength() -> Int {
        guard let engine else { return 0 }
        return Int(vitype_engine_get_buffer_len(engine))
    }

    func getComposedText() -> String {
        guard let engine else { return "" }
        guard let ptr = vitype_engine_get_composed_text(engine) else { return "" }
        let text = String(cString: ptr)
        vitype_engine_free_string(ptr)
        return text
    }
}
