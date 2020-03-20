//
//  ExperienceItem.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 24/02/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import Foundation
struct ExperienceItem : Codable {
    let name : String?
    let startingDate : Date?
    let endDate : Date?
    let description : String?
    
    enum CodingKeys: String, CodingKey {
        
        case name = "name"
        case startingDate = "startingDate"
        case endDate = "endDate"
        case description = "description"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        startingDate = try values.decodeIfPresent(Date.self, forKey: .startingDate)
        endDate = try values.decodeIfPresent(Date.self, forKey: .endDate)
        description = try values.decodeIfPresent(String.self, forKey: .description)
    }
    
}
