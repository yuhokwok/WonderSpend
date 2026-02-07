//
//  Category+Color.swift
//  WonderSpend
//

import SwiftUI

extension Category {
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
