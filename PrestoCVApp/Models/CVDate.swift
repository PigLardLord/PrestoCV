//
//  CVDate.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 22/03/2020.
//  Copyright © 2020 PigLardLord. All rights reserved.
//

import Foundation

struct CVDate : Codable {
    let year : Int?
    let month : Int?
    let day : Int?
    
    enum CodingKeys: String, CodingKey {
        
        case year = "year"
        case month = "month"
        case day = "day"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        year = try values.decodeIfPresent(Int.self, forKey: .year)
        month = try values.decodeIfPresent(Int.self, forKey: .month)
        day = try values.decodeIfPresent(Int.self, forKey: .day)
    }
    
}
