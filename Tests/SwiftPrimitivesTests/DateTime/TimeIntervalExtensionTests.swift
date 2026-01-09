import Foundation
import Testing

@testable
import SwiftPrimitives

struct TimeIntervalExtensionTests {
    @Test
    func testMilliseconds() {
        let valueFromExtension: TimeInterval = .milliseconds(7)
        let valueFromInitializer: TimeInterval = .init(0.007)
        
        #expect(valueFromExtension == valueFromInitializer)
    }

    @Test
    func testSeconds() {
        let valueFromExtension: TimeInterval = .seconds(7)
        let valueFromInitializer: TimeInterval = .init(7)
        
        #expect(valueFromExtension == valueFromInitializer)
    }
    
    @Test
    func testMinutes() {
        let valueFromExtension: TimeInterval = .minutes(7)
        let valueFromInitializer: TimeInterval = .init(420)
        
        #expect(valueFromExtension == valueFromInitializer)
    }

    @Test
    func testHours() {
        let valueFromExtension: TimeInterval = .hours(10)
        let valueFromInitializer: TimeInterval = .init(10 * 3600)
        
        #expect(valueFromExtension == valueFromInitializer)
    }
    
    @Test
    func testDays() {
        let valueFromExtension: TimeInterval = .days(3)
        let valueFromInitializer: TimeInterval = .init(3 * 24 * 3600)
        
        #expect(valueFromExtension == valueFromInitializer)
    }

    
}
