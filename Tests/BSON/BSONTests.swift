//
//  BSONTests.swift
//  BSONTests
//
//  Created by Alsey Coleman Miller on 12/13/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import XCTest
import BinaryJSON
import CBSON

class BSONTests: XCTestCase {

    func testUnsafePointer() {

        let document = sampleDocument()

        // create from pointer
        do {

            print("Document: \n\(document)\n")

            guard let unsafePointer = BSON.unsafePointerFromDocument(document)
                else { XCTFail("Could not create unsafe pointer"); return }

            defer { bson_destroy(unsafePointer) }

            guard let newDocument = BSON.documentFromUnsafePointer(unsafePointer)
                else { XCTFail("Could not create document from unsafe pointer"); return }

            print("New Document: \n\(document)\n")

            XCTAssert(newDocument == document, "\(newDocument) == \(document)")
        }

        // try to create a 2nd time, to make sure we didnt modify the unsafe pointer
        do {

            guard let unsafePointer = BSON.unsafePointerFromDocument(document)
                else { XCTFail("Could not create unsafe pointer"); return }

            defer { bson_destroy(unsafePointer) }

            guard let newDocument = BSON.documentFromUnsafePointer(unsafePointer)
                else { XCTFail("Could not create document from unsafe pointer"); return }

            XCTAssert(newDocument == document, "\(newDocument) == \(document)")
        }
    }

    func testConvertible() {
        let document: BSON.Document = [
            "string": "string",
            "int": 5,
            "double": 5.123,
            "bool": true,
            "arr": [1,2,3],
            "dict": [
                "key1": "value1",
                "key2": [1,2,3]
            ]
        ]

        XCTAssert(document["string"]?.stringValue == "string")
        XCTAssert(document["int"]?.intValue == 5)
        XCTAssert(document["double"]?.doubleValue == 5.123)
        XCTAssert(document["bool"]?.boolValue == true)
        XCTAssert(document["arr"]!.arrayValue! == [1,2,3])
        XCTAssert(document["dict"]!.documentValue! == ["key1": "value1", "key2": [1,2,3]])
    }

    func testJSON() throws {
        let document: BSON.Document = [
            "string": "string",
            "int": 5,
            "double": 5.123,
            "bool": true,
            "arr": [1,2,3],
            "dict": [
                "key1": "value1",
                "key2": [1,2,3]
            ]
        ]

        let json = BSON.toJSONString(document)

        // lazy checking
        XCTAssert(json.characters.count > 0)

        let documentFromJSON = try BSON.fromJSONString(json)

        XCTAssertEqual(document, documentFromJSON)
    }
}

extension BSONTests {
    static var allTests: [(String, BSONTests -> () throws -> Void)] {
        return [
            ("testUnsafePointer", testUnsafePointer),
            ("testConvertible", testConvertible),
            ("testJSON", testJSON)
        ]
    }
}


// MARK: - Internal

func sampleDocument() -> BSON.Document {

    let time = TimeInterval(Int(TimeIntervalSince1970()))

    // Date is more precise than supported by BSON, so equality fails
    let date = Date(timeIntervalSince1970: time)

    var document = BSON.Document()

    // build BSON document
    do {

        var numbersDocument = BSON.Document()

        numbersDocument["double"] = .Number(.Double(1000.1111))

        numbersDocument["int32"] = .Number(.Integer32(32))

        numbersDocument["int64"] = .Number(.Integer64(64))

        document["numbersDocument"] = .Document(numbersDocument)

        document["string"] = .String("Text")

        document["array"] = .Array([.Document(["key": .Array([.String("subarray string")])])])

        document["objectID"] = .ObjectID(BSON.ObjectID())

        document["data"] = .Binary(BSON.Binary(data: Data(byteValue: [] + "test".utf8)))

        document["datetime"] = .Date(date)

        document["null"] = .Null

        document["regex"] = .RegularExpression(BSON.RegularExpression("pattern", options: ""))

        document["code"] = .Code(BSON.Code("js code"))

        document["code with scope"] = .Code(BSON.Code("JS code", scope: ["myVariable": .String("value")]))

        document["timestamp"] = .Timestamp(BSON.Timestamp(time: 10, oridinal: 1))

        document["minkey"] = .MaxMinKey(.Minimum)

        document["maxkey"] = .MaxMinKey(.Maximum)
    }

    return document
}
