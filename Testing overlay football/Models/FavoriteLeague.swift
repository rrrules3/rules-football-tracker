//
//  FavoriteLeague.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation
import SwiftData

@Model
final class FavoriteLeague {
    @Attribute(.unique) var id: Int       // API-Football league ID
    var name: String                       // e.g. "Premier League"
    var logoURL: String                    // League logo URL
    var country: String                    // e.g. "England"

    init(id: Int, name: String, logoURL: String, country: String) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.country = country
    }
}
