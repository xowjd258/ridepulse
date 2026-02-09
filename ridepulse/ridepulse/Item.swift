// This file is no longer used. Models are in Models/RideModels.swift
// Kept for backward compatibility with SwiftData migrations.

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
