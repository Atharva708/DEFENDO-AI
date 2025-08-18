//
//  SharedTypes.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import Foundation
import UIKit



// MARK: - Severity Levels
enum SeverityLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - Extensions
extension SeverityLevel {
    var color: UIColor {
        switch self {
        case .low:
            return .systemGreen
        case .medium:
            return .systemOrange
        case .high:
            return .systemRed
        case .critical:
            return .systemPurple
        }
    }
}
