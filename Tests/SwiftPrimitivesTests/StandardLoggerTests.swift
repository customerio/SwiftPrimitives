//import Foundation
//import Testing
//
//import SwiftPrimitives
//
//struct StandardLoggerTests {
//
//    @Test
//    func testLogLevelNoneWithoutTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .none,
//            destination: outputter
//        )
//
//        logger.debug("Test debug message")
//        logger.info("Test info message")
//        logger.error("Test error message")
//
//        #expect(!outputter.hasMessages)
//    }
//
//    @Test
//    func testLogLevelNoneWithTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .none,
//            destination: outputter
//        )
//
//        logger.debug("Test debug message", "anyTag")
//        logger.info("Test info message", "anyTag")
//        logger.error("Test error message", "anyTag", nil)
//
//        
//        #expect(!outputter.hasMessages)
//    }
//
//    @Test
//    func testLogLevelErrorWithoutTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .error,
//            destination: outputter
//        )
//
//        outputter.clear()
//        logger.logLevel = .error
//
//        logger.debug("Test debug message")
//        logger.info("Test info message")
//        let errorMessage = "Test error message"
//        logger.error(errorMessage)
//
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 1)
//        #expect(outputter.debugMessages.isEmpty)
//        #expect(outputter.infoMessages.isEmpty)
//        #expect(outputter.errorMessages.count == 1)
//        
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .error,
//            content: errorMessage
//        )))
//    }
//
//    @Test
//    func testLogLevelErrorWithTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .error,
//            destination: outputter
//        )
//
//        logger.debug("Test debug message", "DebugTag")
//        logger.info("Test info message", "InfoTag")
//        logger.error("Test error message", "ErrorTag")
//
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 1)
//        #expect(outputter.debugMessages.isEmpty)
//        #expect(outputter.infoMessages.isEmpty)
//        #expect(outputter.errorMessages.count == 1)
//
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .error,
//            content: "Test error message",
//            tag: "ErrorTag"
//        )))
//    }
//
//    @Test
//    func testLogLevelErrorWithTagsAndError() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .error,
//            destination: outputter
//        )
//
//        let error = NSError(
//            domain: "io.customer",
//            code: 12,
//            userInfo: [NSLocalizedDescriptionKey: "Localized error"]
//        )
//        logger.logLevel = .error
//
//        logger.debug("Test debug message", "DebugTag")
//        logger.info("Test info message", "InfoTag")
//        logger.error("Test error message", "ErrorTag", error)
//
//        
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 1)
//        #expect(outputter.debugMessages.isEmpty)
//        #expect(outputter.infoMessages.isEmpty)
//        #expect(outputter.errorMessages.count == 1)
//
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .error,
//            content: "Test error message Error: Localized error",
//            tag: "ErrorTag"
//        )))
//    }
//
//    @Test
//    func testLogLevelInfoWithoutTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .info,
//            destination: outputter
//        )
//
//        logger.debug("Test debug message")
//        let infoMessage = "Test info message"
//        logger.info(infoMessage)
//        let errorMessage = "Test error message"
//        logger.error(errorMessage)
//
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 2)
//        #expect(outputter.debugMessages.isEmpty)
//        #expect(outputter.infoMessages.count == 1)
//        #expect(outputter.errorMessages.count == 1)
//
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .info,
//            content: infoMessage
//        )))
//
//        let second = outputter.allMessages[1]
//        #expect(second.hasContentMatching(LogMessage(
//            level: .error,
//            content: errorMessage
//        )))
//    }
//
//    @Test
//    func testLogLevelInfoWithTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .info,
//            destination: outputter
//        )
//
//        logger.debug("Test debug message", "DebugTag")
//        logger.info("Test info message", "InfoTag")
//        logger.error("Test error message", "ErrorTag")
//        
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 2)
//        #expect(outputter.debugMessages.isEmpty)
//        #expect(outputter.infoMessages.count == 1)
//        #expect(outputter.errorMessages.count == 1)
//
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .info,
//            content: "Test info message",
//            tag: "InfoTag"
//        )))
//
//        let second = outputter.allMessages[1]
//        #expect(second.hasContentMatching(LogMessage(
//            level: .error,
//            content: "Test error message",
//            tag: "ErrorTag"
//        )))
//    }
//
//    @Test
//    func testLogLevelDebugWithoutTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .debug,
//            destination: outputter
//        )
//
//        let debugMessage = "Test debug message"
//        logger.debug(debugMessage)
//        let infoMessage = "Test info message"
//        logger.info(infoMessage)
//        let errorMessage = "Test error message"
//        logger.error(errorMessage)
//
//        
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 3)
//        #expect(outputter.debugMessages.count == 1)
//        #expect(outputter.infoMessages.count == 1)
//        #expect(outputter.errorMessages.count == 1)
//
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .debug,
//            content: debugMessage
//        )))
//        #expect(outputter.firstDebugMessage?.content == debugMessage)
//
//        let second = outputter.allMessages[1]
//        #expect(second.hasContentMatching(LogMessage(
//            level: .info,
//            content: infoMessage
//        )))
//        #expect(outputter.firstInfoMessage?.content == infoMessage)
//
//        let third = outputter.allMessages[2]
//        #expect(third.hasContentMatching(LogMessage(
//            level: .error,
//            content: errorMessage
//        )))
//        #expect(outputter.firstErrorMessage?.content == errorMessage)
//    }
//
//    @Test
//    func testLogLevelDebugWithTags() {
//        let outputter = AccumulatorLogDestination()
//        let logger = StandardLogger(
//            logLevel: .info,
//            destination: outputter
//        )
//
//        let debugMessage = "Test debug message"
//        logger.debug(debugMessage, "DebugTag")
//        let infoMessage = "Test info message"
//        logger.info(infoMessage, "InfoTag")
//        let errorMessage = "Test error message"
//        logger.error(errorMessage, "ErrorTag")
//
//        
//        #expect(outputter.hasMessages)
//        #expect(outputter.allMessages.count == 3)
//        #expect(outputter.debugMessages.count == 1)
//        #expect(outputter.infoMessages.count == 1)
//        #expect(outputter.errorMessages.count == 1)
//
//        
//        let first = outputter.allMessages[0]
//        #expect(first.hasContentMatching(LogMessage(
//            level: .debug,
//            content: debugMessage,
//            tag: "DebugTag"
//        )))
//        #expect(outputter.firstDebugMessage?.content == debugMessage)
//
//        let second = outputter.allMessages[1]
//        #expect(second.hasContentMatching(LogMessage(
//            level: .info,
//            content: infoMessage,
//            tag: "InfoTag"
//        )))
//        #expect(outputter.firstInfoMessage?.content == infoMessage)
//
//        let third = outputter.allMessages[2]
//        #expect(third.hasContentMatching(LogMessage(
//            level: .error,
//            content: errorMessage,
//            tag: "ErrorTag"
//        )))
//        #expect(outputter.firstErrorMessage?.content == errorMessage)
//    }
//}
//
