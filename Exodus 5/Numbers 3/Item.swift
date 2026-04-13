//
//  Item.swift
//  Exodus 8
//
//  Created by Thomas Kane on 4/11/26.
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
