//
//  CategoryTotal.swift
//  WonderSpend
//

import Foundation

struct CategoryTotal: Identifiable {
    let id: UUID
    let category: Category
    let total: Double

    init(category: Category, total: Double) {
        self.id = category.id
        self.category = category
        self.total = total
    }
}
