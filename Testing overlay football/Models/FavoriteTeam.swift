//
//  FavoriteTeam.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import Foundation
import SwiftData

@Model
final class FavoriteTeam {
    @Attribute(.unique) var id: Int       // API-Football team ID
    var name: String                       // e.g. "Arsenal"
    var logoURL: String                    // URL to team crest image
    var leagueID: Int                      // Primary league ID

    init(id: Int, name: String, logoURL: String, leagueID: Int) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.leagueID = leagueID
    }
}
