//
//  Item.swift
//  InterCommerce-iOS
//
//  Created by Felipe Calderon Barragan on 9/08/26.
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
