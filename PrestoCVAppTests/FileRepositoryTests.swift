//
//  FileRepositoryTests.swift
//  PrestoCVAppTests
//
//  Created by Giovanni Trovato on 22/03/2020.
//  Copyright © 2020 PigLardLord. All rights reserved.
//

import XCTest
@testable import PrestoCVApp

fileprivate var jsonCVString = """
{
  "name": "name",
  "id": "8D31B96A-02AC-4531-976F-A455686F8FE2",
  "header": {
    "image": "String",
    "introduction": "String"
  },
  "personalData": {
    "name": "String",
    "surname": "String",
    "tel": "String",
    "address": "String"
  },
  "workingExperiences": [
    {
      "name": "String",
      "startingDate": {
        "year": 2020,
        "month": 4,
        "day": 22
      },
      "endDate": {
        "year": 2020,
        "month": 4,
        "day": 22
      },
      "description": "String"
    }
  ],
  "educations": [
    {
      "name": "String",
      "startingDate": {
        "year": 2020,
        "month": 4,
        "day": 22
      },
      "endDate": {
        "year": 2020,
        "month": 4,
        "day": 22
      },
      "description": "String"
    }
  ],
  "teckSkills": [
    {
      "title": "String",
      "level": 5
    }
  ],
  "personalSkills": [
    {
      "title": "String",
      "level": 5
    }
  ]
}
"""

class FileRepositoryTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_saving_cv_succeed() {
        let repo = FileCVRepository(searchPathDir: .documentDirectory)
        var cv = try! CV.from(string: jsonCVString)
        let id = UUID()
        cv.id = id
        
        repo.add(curriculum: cv)
        
        let loadedcv = repo.get(with: id)
        XCTAssert(loadedcv.id == id)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

}
