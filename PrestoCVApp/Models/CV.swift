//
//  CV.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 20/03/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import Foundation

struct CV : Codable {
    let header : Header?
    let personalData : PersonalData?
    let workingExperiences : [ExperienceItem]?
    let educations : [ExperienceItem]?
    let teckSkills : [Skill]?
    let personalSkills : [Skill]?
    
    enum CodingKeys: String, CodingKey {
        
        case header = "header"
        case personalData = "personalData"
        case workingExperiences = "workingExperiences"
        case educations = "educations"
        case teckSkills = "teckSkills"
        case personalSkills = "personalSkills"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        header = try values.decodeIfPresent(Header.self, forKey: .header)
        personalData = try values.decodeIfPresent(PersonalData.self, forKey: .personalData)
        workingExperiences = try values.decodeIfPresent([ExperienceItem].self, forKey: .workingExperiences)
        educations = try values.decodeIfPresent([ExperienceItem].self, forKey: .educations)
        teckSkills = try values.decodeIfPresent([Skill].self, forKey: .teckSkills)
        personalSkills = try values.decodeIfPresent([Skill].self, forKey: .personalSkills)
    }
    
}
