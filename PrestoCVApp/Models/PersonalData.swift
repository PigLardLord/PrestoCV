//
//  PersonalData.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 24/02/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import Foundation
struct PersonalData : Codable {
    let name : String?
    let surname : String?
    let tel : String?
    let address : String?
    
    enum CodingKeys: String, CodingKey {
        
        case name = "name"
        case surname = "surname"
        case tel = "tel"
        case address = "address"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        surname = try values.decodeIfPresent(String.self, forKey: .surname)
        tel = try values.decodeIfPresent(String.self, forKey: .tel)
        address = try values.decodeIfPresent(String.self, forKey: .address)
    }
    
}
