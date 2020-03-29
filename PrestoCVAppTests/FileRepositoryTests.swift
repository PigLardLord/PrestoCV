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

    var repo: CVRepository!
    var url: URL!
    
    override func setUp() {
        let base = NSTemporaryDirectory()
        let sub = "TEST"
        repo = FileCVRepository(baseDirectory: base, subdir: sub)
        url = URL(fileURLWithPath: base).appendingPathComponent(sub)
    }

    override func tearDown() {
        clearTempFolder()
    }

    func test_saving_cv_succeed() {
        var cv = try! CV.from(string: jsonCVString)
        let id = UUID()
        cv.id = id
        
        repo.add(curriculum: cv)
        
        let loadedcv = repo.get(with: id)
        XCTAssert(loadedcv.id == id)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func test_save_more_cv_succeed() {
        var cv1 = try! CV.from(string: jsonCVString)
        let id1 = UUID()
        cv1.id = id1
        
        var cv2 = try! CV.from(string: jsonCVString)
        let id2 = UUID()
        cv2.id = id2
        
        repo.add(curriculum: cv1)
        repo.add(curriculum: cv2)
        
        
        
        let loadedcvs = repo.getAll()
        XCTAssert(loadedcvs.count == 2)
    }
    
    private func clearTempFolder() {
        let fileManager = FileManager.default
        
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: url.path)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: url.appendingPathComponent(filePath).path)
            }
        } catch {
            print("Could not clear temp folder: \(error)")
        }
    }
}
