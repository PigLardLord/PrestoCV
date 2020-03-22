//
//  Header.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 24/02/2020.
//  Copyright © 2020 PigLardLord. All rights reserved.
//

import Foundation
struct Header : Codable {
    let image : String?
    let introduction : String?
    
    enum CodingKeys: String, CodingKey {
        
        case image = "image"
        case introduction = "introduction"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        image = try values.decodeIfPresent(String.self, forKey: .image)
        introduction = try values.decodeIfPresent(String.self, forKey: .introduction)
    }
    
}
