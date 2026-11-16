//
//  WriteRetryTests.swift
//  NetworkingTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import Networking
import Testing

@Suite("Pending writes")
struct WriteRetryTests {
    @Test("A timed-out or abandoned write may still land")
    func pendingErrors() {
        #expect(writeMayStillLand(NetworkingError.timeout))
        #expect(writeMayStillLand(CancellationError()))
    }

    @Test("A refused write will not land")
    func refusedErrors() {
        #expect(!writeMayStillLand(NetworkingError.notAuthorized))
        #expect(!writeMayStillLand(NetworkingError.unsupportedVersion))
        #expect(!writeMayStillLand(URLError(.badServerResponse)))
    }
}
