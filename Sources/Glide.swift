import Foundation

/// One axis of smooth scrolling: a critically damped spring chasing the requested distance.
/// Velocity stays continuous between wheel ticks, so the motion does not pulse.
struct Glide {
    private var left = 0.0      // distance still to travel
    private var velocity = 0.0
    private var carry = 0.0     // sub-pixel remainder

    var isDone: Bool { left == 0 }

    mutating func add(_ distance: Double) {
        // Reversing direction drops the leftover glide.
        if distance * left < 0 { self = Glide() }
        left = min(max(left + distance, -20_000), 20_000)
    }

    /// Advances by dt seconds and returns the whole pixels to scroll now.
    mutating func step(dt: Double, stiffness: Double) -> Int32 {
        guard left != 0 else { return 0 }
        let x = -left
        let b = velocity + stiffness * x
        let decay = exp(-stiffness * dt)
        var next = (x + b * dt) * decay
        velocity = (velocity - stiffness * b * dt) * decay
        var moved = next - x
        if abs(next) < 0.5 {
            moved = left
            next = 0
            velocity = 0
        }
        left = -next
        carry += moved
        let whole = carry.rounded(left == 0 ? .toNearestOrAwayFromZero : .towardZero)
        carry = left == 0 ? 0 : carry - whole
        return Int32(whole)
    }
}
