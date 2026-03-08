//
//  Item.swift
//  Glowing
//
//  Created by Mesbah Tanvir on 2026-03-08.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
