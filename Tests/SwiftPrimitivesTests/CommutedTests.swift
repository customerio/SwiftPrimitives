//
//  CommutedTests.swift
//  SwiftPrimitives
//
//  Created by Holly Schilling on 12/31/25.
//

import Foundation
import Testing

import SwiftPrimitives

struct CommutedTests {
    
    // MARK: - Wrapping and Equality Tests
    
    @Test
    func testEquatableInt() {
        let first = 1.commute()
        let second = Commuted.int(1)
        let third = Commuted.int(2)
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == 1)
        #expect(first != 2)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableString() {
        let first = "a".commute()
        let second = Commuted.string("a")
        let third = Commuted.string("c")
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == "a")
        #expect(first != "d")
        #expect(first != 1)
    }
    
    @Test
    func testEquatableFloat() {
        let first = 1.5.commute()
        let second = Commuted.float(1.5)
        let third = Commuted.float(1.6)
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == 1.5)
        #expect(first != 1.6)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableBool() {
        let first = true.commute()
        let second = Commuted.bool(true)
        let third = Commuted.bool(false)
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == true)
        #expect(first != false)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableDate() async throws {
        let now = Date.now
        let later = now.addingTimeInterval(100)
        let first = now.commute()
        let second = Commuted.date(now)
        let third = Commuted.date(later)
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == now)
        #expect(first != later)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableData() async throws {
        let initial = "Hello".data(using: .utf8)!
        let more = "Hello World".data(using: .utf8)!
        let first = initial.commute()
        let second = Commuted.data(initial)
        let third = Commuted.data(more)
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == initial)
        #expect(first != more)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableArray() {
        let initial = [1, 2, 3]
        let more = [1, 2, 3, 4]
        let first = initial.commute()
        let second = Commuted.array(initial.map { $0.commute() })
        let third = more.commute()
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == initial)
        #expect(first != more)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableObject() {
        let initial = [
            "first": 1,
            "second": 2,
            "third": 3
        ]
        let more = [
            "first": 1,
            "second": 2,
            "third": 3,
            "fourth": 4
        ]
        let first = initial.commute()
        let second = Commuted.object(initial.mapValues { $0.commute() })
        let third = more.commute()
        
        #expect(first == first)
        #expect(first == second)
        #expect(first != third)
        #expect(first == initial)
        #expect(first != more)
        #expect(first != "a")
    }
    
    @Test
    func testEquatableOptional() {
        let nullString: String? = nil
        let hello: String? = "hello"
        let nullInt: Int? = nil
        let zero: Int? = 0
        
        // Note the difference of the ? which causes the commute function to not be called
        #expect(nullString?.commute() == nil)
        
        // Ensure everything nil should become .null
        #expect(nullString.commute() == .null)
        #expect(nullInt.commute() == .null)
        
        // Null is null, no matter the type
        #expect(nullString.commute() == nullInt.commute())
        
        // Ensure 0 != nil
        #expect(nullInt.commute() != zero.commute())
        
        // Ensure that wrapped Optional can still compare to source
        #expect(zero.commute() == 0)
        #expect(zero.commute() == zero)
        #expect(hello.commute() == "hello")
        #expect(nullString.commute() != hello)
    }
    
    @Test
    func testFloatNaNFiltering() throws {
        let nan: Float = .nan
        
        let commutedNan = nan.commute()
        #expect(commutedNan == .null)
    }
    
    @Test
    func testDoubleNaNFiltering() throws {
        let nan: Double = .nan
        
        let commutedNan = nan.commute()
        #expect(commutedNan == .null)
    }
    
    @Test
    func testFloatInfinityFiltering() throws {
        let infinity: Float = .infinity
        let negativeInfinity: Float = -.infinity
        
        
        let commutedInfinity = infinity.commute()
        let commuteNegativeInfinity = negativeInfinity.commute()
        
        #expect(commutedInfinity == .null)
        #expect(commuteNegativeInfinity == .null)
    }
    
    @Test
    func testDoubleInfinityFiltering() throws {
        let infinity: Double = .infinity
        let negativeInfinity: Double = -.infinity
        
        
        let commutedInfinity = infinity.commute()
        let commuteNegativeInfinity = negativeInfinity.commute()
        
        #expect(commutedInfinity == .null)
        #expect(commuteNegativeInfinity == .null)
    }
    
    @Test
    func testIntAndFloatEquality() {
        let int: Int = 10
        let float: Float = 10.0
        
        #expect(int.commute() == float.commute())
        #expect(float.commute() == int.commute())
    }
    
    // MARK: JSON Encoding tests
    
    @Test
    func testJsonEncodingNull() throws {
        let commuted = Commuted.null
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect("null" == stringResult)

    }
    
    @Test(arguments: zip([false, true], ["false", "true"]))
    func testJsonEncodeBool(input: Bool, expected: String) throws {
        let commuted = input.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip([0, 1, -123], ["0", "1", "-123"]))
    func testJsonEncodeInt(input: Int, expected: String) throws {
        let commuted = input.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip([0 as Float, 1, 19.5, -2_000_000, Float.nan, Float.infinity], [ "0", "1", "19.5", "-2000000", "null", "null"]))
    func testJsonEncodeFloat(input: Float, expected: String) throws {
        let commuted = input.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip([0, 1, 19.5, -2_000_000, Double.nan, Double.infinity], [ "0", "1", "19.5", "-2000000", "null", "null"]))
    func testJsonEncodeDouble(input: Double, expected: String) throws {
        let commuted = input.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip([1767225600, 1000212360], ["\"2026-01-01T00:00:00Z\"", "\"2001-09-11T12:46:00Z\""]))
    func testJsonEncodeDate(input: TimeInterval, expected: String) throws {
        
        // Swift Date(timeIntervalSince1970: _) uses local time.
        // Swift Date(timeIntervalSinceReferenceDate: _) uses UTC.
        // To ensure tests pass no matter where they are run, we
        // convert the epoch timestamps relative to the Swift
        // Reference Date of 2001-01-01 at Midnight UTC.
        let EpochOffset: TimeInterval = 978307200
        let date = Date(timeIntervalSinceReferenceDate: input - EpochOffset)
        let commuted = date.commute()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip(["first", "", "😄", "\"Quoted\""], [ "\"first\"", "\"\"", "\"😄\"", "\"\\\"Quoted\\\"\""]))
    func testJsonEncodeString(input: String, expected: String) throws {
        let commuted = input.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip([[1, 2, 3] as [Sendable & Commutable], ["first", "second"] as [Sendable & Commutable]], ["[1,2,3]", "[\"first\",\"second\"]"]))
    func testJsonEncodeArray(input: [Sendable & Commutable], expected: String) throws {
        // We have to remove the Sendable property before we can call `commute()`
        let commuted = input.map { $0 as Commutable }.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    @Test(arguments: zip([
        ["number": 1] as [String: Sendable & Commutable],
        ["string": "hello"] as [String: Sendable & Commutable],
        ["array": [1,2,3]] as [String: Sendable & Commutable]
    ], [
        "{\"number\":1}",
        "{\"string\":\"hello\"}",
        "{\"array\":[1,2,3]}"
    ]))
    func testJsonEncodeDictionary(input: [String: Sendable & Commutable], expected: String) throws {
        // We have to remove the Sendable property before we can call `commute()`
        let commuted = input.mapValues { $0 as Commutable }.commute()
        
        let encoder = JSONEncoder()
        let result = try encoder.encode(commuted)
        let stringResult = String(data: result, encoding: .utf8)!
        
        #expect(expected == stringResult)
    }
    
    // MARK: - Decoding Tests
    
    @Test(arguments: zip(["true", "false"], [true, false]))
    func testJsonDecodeBool(input: String, expected: Bool) throws {
        let decoder = JSONDecoder()
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)
        
        #expect(expected.commute() == result)
    }
    
    @Test(arguments: zip(["31415", "0", "-7"], [31415, 0, -7]))
    func testJsonDecodeInt(input: String, expected: Int) throws {
        let decoder = JSONDecoder()
        // All Numeric values get parsed as dates if no dateDecodingStrategy is set
        decoder.dateDecodingStrategy = .iso8601
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)
        
        #expect(expected.commute() == result)
    }

    @Test(arguments: zip(["314.15", "0", "-200"], [314.15, 0, -200]))
    func testJsonDecodeFloat(input: String, expected: Double) throws {
        let decoder = JSONDecoder()
        // All Numeric values get parsed as dates if no dateDecodingStrategy is set
        decoder.dateDecodingStrategy = .iso8601
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)
        // Numeric values without decimals are assumed to be Integers, but
        // we can implicitly compare them.
        #expect(expected.commute() == result)
    }

    @Test(arguments: zip([ "\"first\"", "\"\"", "\"😄\"", "\"\\\"Quoted\\\"\""], ["first", "", "😄", "\"Quoted\""]))
    func testJsonDecodeString(input: String, expected: String) throws {
        let decoder = JSONDecoder()
        // All Numeric values get parsed as dates if no dateDecodingStrategy is set
        decoder.dateDecodingStrategy = .iso8601
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)

        #expect(expected.commute() == result)
    }

    @Test(arguments: zip(["\"2026-01-01T00:00:00Z\"", "\"2001-09-11T12:46:00Z\""], [1767225600, 1000212360]))
    func testJsonDecodeDate(input: String, expected: TimeInterval) throws {

        // Swift Date(timeIntervalSince1970: _) uses local time.
        // Swift Date(timeIntervalSinceReferenceDate: _) uses UTC.
        // To ensure tests pass no matter where they are run, we
        // convert the epoch timestamps relative to the Swift
        // Reference Date of 2001-01-01 at Midnight UTC.
        let EpochOffset: TimeInterval = 978307200
        let date = Date(timeIntervalSinceReferenceDate: expected - EpochOffset)

        let decoder = JSONDecoder()
        // All Numeric values get parsed as dates if no dateDecodingStrategy is set
        decoder.dateDecodingStrategy = .iso8601
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)

        #expect(date.commute() == result)
    }

    @Test(arguments: zip( ["[1,2,3]", "[\"first\",\"second\"]"], [[1, 2, 3] as [Sendable & Commutable], ["first", "second"] as [Sendable & Commutable]]))
    func testJsonDecodeArray(input: String, expected: [Sendable & Commutable]) throws {
        // We have to remove the Sendable property before we can call `commute()`
        let commuted = expected.map { $0 as Commutable }.commute()
        
        let decoder = JSONDecoder()
        // All Numeric values get parsed as dates if no dateDecodingStrategy is set
        decoder.dateDecodingStrategy = .iso8601
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)
        
        #expect(commuted == result)
    }
    
    @Test(arguments: zip([
        "{\"number\":1}",
        "{\"string\":\"hello\"}",
        "{\"array\":[1,2,3], \"null\": null}"
    ], [
        ["number": 1] as [String: Sendable & Commutable],
        ["string": "hello"] as [String: Sendable & Commutable],
        ["array": [1,2,3], "null": nil] as [String: Sendable & Commutable]
    ]))
    func testJsonDecodeObject(input: String, expected: [String: Sendable & Commutable]) throws {
        // We have to remove the Sendable property before we can call `commute()`
        let commuted = expected.mapValues { $0 as Commutable }.commute()
        
        let decoder = JSONDecoder()
        // All Numeric values get parsed as dates if no dateDecodingStrategy is set
        decoder.dateDecodingStrategy = .iso8601
        let data = input.data(using: .utf8)!
        let result = try decoder.decode(Commuted.self, from: data)
        
        #expect(commuted == result)
    }
    
    public static func plistWrapper(content: String) -> Data {
        let xmlHeader = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
        """
        let xmlFooter = "</plist>"
        let fullString = xmlHeader + content + xmlFooter
        return fullString.data(using: .utf8, allowLossyConversion: false)!
    }
    
    @Test(arguments: zip(["<data>3q2+7w==</data>"], [Data([0xde, 0xad, 0xbe, 0xef])]))
    func testPlistDecodeData(input: String, expected: Data) throws {

        let wrappedContent = Self.plistWrapper(content: input)
        let decoder = PropertyListDecoder()
        let result = try decoder.decode(Commuted.self, from: wrappedContent)
        
        #expect(expected.commute() == result)
    }
    
    @Test
    func testPlistEncodeNull() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(["null": nil] as [String: String?])
        let string = String(data: data, encoding: .utf8)!
        print(string)
    }
    
    
}
