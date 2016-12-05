//
//  {PROJECT}Tests.swift
//  {ORGANIZATION}
//
//  Created by {AUTHOR} on {{TODAY}}.
//  Copyright © {YEAR} {ORGANIZATION}. All rights reserved.
//

import Foundation
import XCTest
import {PROJECT}

class {PROJECT}Tests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        //// XCTAssertEqual({PROJECT}().text, "Hello, World!")
    }
}

#if os(Linux)
extension {PROJECT}Tests {
    static var allTests : [(String, ({PROJECT}Tests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
#endif
