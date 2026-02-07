//
//  CategoryColorPalette.swift
//  WonderSpend
//

import Foundation

enum CategoryColorPalette {
    private static let colors = [
        "#4A5568", "#DD6B20", "#2B6CB0", "#D53F8C",
        "#805AD5", "#38A169", "#D69E2E", "#319795"
    ]

    static func colorHex(for name: String) -> String {
        let hash = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) })
        return colors[hash % colors.count]
    }
}
