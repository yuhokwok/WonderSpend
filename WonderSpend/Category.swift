//
//  Category.swift
//  WonderSpend
//
//  Created by Yu Ho Kwok on 2/5/26.
//

import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var colorHex: String

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        colorHex: String
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
    }
}
