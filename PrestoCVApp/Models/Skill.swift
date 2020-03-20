//
//  Skill.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 24/02/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import Foundation
struct Skill : Codable {
    let title : String?
    let level : Int?
    
    enum CodingKeys: String, CodingKey {
        
        case title = "title"
        case level = "level"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        level = try values.decodeIfPresent(Int.self, forKey: .level)
    }
    
}
