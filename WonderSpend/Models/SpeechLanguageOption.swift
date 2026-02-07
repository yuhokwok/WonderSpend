//
//  SpeechLanguageOption.swift
//  WonderSpend
//

enum SpeechLanguageOption: String, CaseIterable {
    case englishUS = "en-US"
    case englishUK = "en-GB"
    case cantoneseHK = "zh-HK"
    case mandarinTW = "zh-TW"
    case mandarinCN = "zh-CN"

    var title: String {
        switch self {
        case .englishUS:
            return "English (US)"
        case .englishUK:
            return "English (UK)"
        case .cantoneseHK:
            return "Cantonese (Hong Kong)"
        case .mandarinTW:
            return "Chinese (Taiwan)"
        case .mandarinCN:
            return "Chinese (China)"
        }
    }
}
