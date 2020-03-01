//
//  CV.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 28/02/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import Foundation

protocol CV{
    var header : Header {get}
    var personalData : PersonalData { get }
    var workingExperiences :[WorkEsperience] {get}
    var educations: [EducationItem] {get}
    var teckSkills: [Skill] {get}
    var personalSkills: [Skill] {get}
}

protocol Header {
    var image: String { get }
    var introduction: String { get }
}

protocol PersonalData {
    var name: String { get }
    var surname: String { get }
    var tel: String { get }
    var address: String { get }
}

protocol WorkEsperience {
    var name: String { get }
    var startingDate: Date { get }
    var endDate: Date { get }
    var description: String { get }
}

protocol EducationItem: WorkEsperience {
    
}

protocol Skill {
    var title: String { get }
    var level: Int { get }
}

