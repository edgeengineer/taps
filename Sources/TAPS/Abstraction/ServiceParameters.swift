// MARK: - Service Parameters

/// Base protocol for service parameters
public protocol ServiceParameters: Sendable {}

/// Client service parameters
public protocol ClientServiceParameters: ServiceParameters {}

/// Server service parameters
public protocol ServerServiceParameters: ServiceParameters {}

/// Protocol for parameters with defaults
public protocol ServiceParametersWithDefaults: ServiceParameters {
    static var defaultParameters: Self { get }
}

/// Client service parameters with defaults
public protocol ClientServiceParametersWithDefaults: ClientServiceParameters, ServiceParametersWithDefaults {}

/// Server service parameters with defaults  
public protocol ServerServiceParametersWithDefaults: ServerServiceParameters, ServiceParametersWithDefaults {}

/// Protocol for services that support default parameters
public protocol ServiceWithDefaults {
    associatedtype Parameters
    static var defaultParameters: Parameters { get }
}

/// Default empty parameters for services that don't need configuration
public struct DefaultParameters: ClientServiceParameters, ServerServiceParameters {
    public init() {}
}
