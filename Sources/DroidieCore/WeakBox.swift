import Foundation

/// Sendable wrapper around a weak reference. Older Swift toolchains (pre-6.x strict
/// concurrency) reject `[weak self]` captures inside `@Sendable` closures as
/// "reference to captured var in concurrently-executing code"; boxing the weak
/// reference in an immutable, @unchecked Sendable class compiles everywhere.
final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
