//
//  CVRepository.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 22/03/2020.
//  Copyright © 2020 PigLardLord. All rights reserved.
//

import Foundation

protocol CVRepository {
    func getAll() -> [CV]
    func get(with id: UUID) -> CV
    func add(curriculum: CV)
    func update(curriculum: CV)
}
