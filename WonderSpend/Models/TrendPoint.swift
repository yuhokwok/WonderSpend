//
//  TrendPoint.swift
//  WonderSpend
//

import Foundation

struct TrendPoint: Identifiable {
    let id: Date
    let date: Date
    let total: Double

    init(date: Date, total: Double) {
        self.id = date
        self.date = date
        self.total = total
    }
}
