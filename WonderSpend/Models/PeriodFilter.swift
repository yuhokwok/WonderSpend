//
//  PeriodFilter.swift
//  WonderSpend
//

enum PeriodFilter: String, CaseIterable {
    case day
    case week
    case month
    case year
    case custom

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        case .custom:
            return "Custom"
        }
    }
}
