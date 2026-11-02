/// Values to include in debug store logs. Logging is disabled in release builds.
public struct LoggingOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Every action processed by the reducer, including actions returned by effects.
    public static let action = Self(rawValue: 1 << 0)
    /// The current state when configured and the state after each processed action.
    public static let state = Self(rawValue: 1 << 1)
    public static let all: Self = [.action, .state]
}
