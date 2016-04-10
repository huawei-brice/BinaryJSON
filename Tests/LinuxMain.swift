import XCTest

@testable import BSONTestSuite

XCTMain([
   testCase(BSONTests.allTests),
])
