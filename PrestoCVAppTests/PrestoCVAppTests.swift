//
//  PrestoCVAppTests.swift
//  PrestoCVAppTests
//
//  Created by Giovanni Trovato on 24/02/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import XCTest
@testable import PrestoCVApp

class PrestoCVAppTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        let sut:CV = Loader.fetch()
        
        XCTAssertTrue(sut.educations?.count == 1)
    }

    

}


private extension Loader {
    static func fetch() -> CV {
        let decoder = JSONDecoder()
        let curriculum = try! decoder.decode(CV.self, from: Data(repeating: 1, count: 1))
        return curriculum
    }
}
