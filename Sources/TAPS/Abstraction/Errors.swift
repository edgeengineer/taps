// Errors.swift
// Typed error definitions for TAPS

/// Main TAPS system errors
public enum TAPSError: Error, Sendable {
    case connectionFailed(String)
    case allCandidatesFailed([String])
    case invalidConfiguration(String)
    case networkUnavailable
    case timeoutExpired
    case serviceUnavailable(String)
    case invalidParameters(String)
}

/// Connection-specific errors
public enum ConnectionError: Error, Sendable {
    case establishmentFailed(String)
    case alreadyClosed
    case invalidState(current: String, expected: String)
    case protocolMismatch
    case addressResolutionFailed
}

/// Message validation errors
public enum MessageValidationError: Error, Sendable {
    case invalidFormat(expected: String, got: String)
    case sizeMismatch(expected: Int, got: Int)
    case contentTooLarge(size: Int, maximum: Int)
}
