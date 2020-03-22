//
//  CV.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 20/03/2020.
//  Copyright © 2020 PigLardLord. All rights reserved.
//

import Foundation

struct CV : Codable {
    var id: UUID
    let name: String
    let header : Header?
    let personalData : PersonalData?
    let workingExperiences : [ExperienceItem]?
    let educations : [ExperienceItem]?
    let teckSkills : [Skill]?
    let personalSkills : [Skill]?
    
//    enum CodingKeys: String, CodingKey {
//        case id
//        case name
//        case header = "header"
//        case personalData = "personalData"
//        case workingExperiences = "workingExperiences"
//        case educations = "educations"
//        case teckSkills = "teckSkills"
//        case personalSkills = "personalSkills"
//    }
    
//    init(from decoder: Decoder) throws {
//        let values = try decoder.container(keyedBy: CodingKeys.self)
//        header = try values.decode(Header.self, forKey: .header)
//        personalData = try values.decode(PersonalData.self, forKey: .personalData)
//        workingExperiences = try values.decodeIfPresent([ExperienceItem].self, forKey: .workingExperiences)
//        educations = try values.decodeIfPresent([ExperienceItem].self, forKey: .educations)
//        teckSkills = try values.decodeIfPresent([Skill].self, forKey: .teckSkills)
//        personalSkills = try values.decodeIfPresent([Skill].self, forKey: .personalSkills)
//        id = try values.decode(UUID.self, forKey: .id)
//        name = try values.decode(String.self, forKey: .name)
//    }
    
    static func from(string: String) throws -> CV{
        let data = string.data(using: .utf8)!
        let responseModel = try from(data: data)
        return responseModel
    }
    
    static func from(data: Data) throws -> CV{
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        let responseModel = try jsonDecoder.decode(CV.self, from: data)
        return responseModel
    }
    
}
