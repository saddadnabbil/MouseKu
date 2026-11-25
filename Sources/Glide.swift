import Foundation

/// One scroll event to post. Phase values match CGScrollPhase and CGMomentumScrollPhase.
struct ScrollFrame: Equatable {
    var delta: Int32
    var scroll: Int64 = 0    // 1 began, 2 changed, 4 ended
    var momentum: Int64 = 0  // 1 begin, 2 continue, 3 end
}

/// Smooth scrolling along one axis, shaped like a trackpad gesture:
/// while the wheel turns, a critically damped spring follows the requested distance;
/// once it goes quiet, the page coasts and slows down.
struct Glide {
    static let releaseDelay = 0.1   // quiet time that counts as "fingers lifted"
    static let stopSpeed = 25.0     // px/s where coasting ends
    static let catchSpeed = 100.0   // above this, an opposite tick only stops the page

    private enum State { case idle, drag, momentum }
    private var state = State.idle
    private var left = 0.0          // drag: distance still to travel
    private var velocity = 0.0
    private var carry = 0.0         // sub-pixel remainder
    private var quiet = 0.0
    private var started = false     // first event of the current phase was sent
    private var stiffness = 14.0
    private var friction = 0.4      // coasting time constant in seconds
    private var coasts = true

    var isDone: Bool { state == .idle }

    mutating func add(_ distance: Double, smoothness: Double, coasts: Bool) -> [ScrollFrame] {
        let s = min(max(smoothness, 0), 1)
        let opposite = distance * (state == .drag ? left : velocity) < 0
        var frames: [ScrollFrame] = []
        if state == .momentum && opposite && abs(velocity) > Self.catchSpeed {
            return cancel()
        }
        if state == .momentum || opposite { frames = close(keepVelocity: !opposite) }
        stiffness = 28 - 18 * s
        friction = 0.08 + 0.4 * s
        self.coasts = coasts
        if state == .idle {
            state = .drag
            started = false
            // Carried speed needs enough distance ahead, or the spring would overshoot.
            left = velocity / stiffness
        }
        left = min(max(left + distance, -20_000), 20_000)
        quiet = 0
        return frames
    }

    mutating func step(dt: Double) -> [ScrollFrame] {
        switch state {
        case .idle:
            return []
        case .drag:
            quiet += dt
            let x = -left
            let b = velocity + stiffness * x
            let decay = exp(-stiffness * dt)
            var next = (x + b * dt) * decay
            velocity = (velocity - stiffness * b * dt) * decay
            var moved = next - x
            if abs(next) < 0.5 {
                moved = left
                next = 0
            }
            left = -next
            var frames = emit(moved)
            if coasts && quiet >= Self.releaseDelay {
                // Coast at the current speed, but never fall short of the distance still owed.
                let owed = left / friction
                var speed = abs(owed) > abs(velocity) ? owed : velocity
                speed = min(max(speed, -12_000), 12_000)
                frames += close(keepVelocity: false)
                if abs(speed) > Self.stopSpeed {
                    state = .momentum
                    started = false
                    velocity = speed
                }
            } else if left == 0 && quiet >= Self.releaseDelay {
                frames += close(keepVelocity: false)
            }
            return frames
        case .momentum:
            let decay = exp(-dt / friction)
            let moved = velocity * friction * (1 - decay)
            velocity *= decay
            var frames = emit(moved)
            if abs(velocity) <= Self.stopSpeed { frames += cancel() }
            return frames
        }
    }

    /// Stops all motion and returns the event that ends the current phase.
    mutating func cancel() -> [ScrollFrame] {
        close(keepVelocity: false)
    }

    private mutating func close(keepVelocity: Bool) -> [ScrollFrame] {
        var frames: [ScrollFrame] = []
        if started && state == .drag { frames.append(ScrollFrame(delta: 0, scroll: 4)) }
        if started && state == .momentum { frames.append(ScrollFrame(delta: 0, momentum: 3)) }
        state = .idle
        started = false
        left = 0
        carry = 0
        if !keepVelocity { velocity = 0 }
        return frames
    }

    private mutating func emit(_ moved: Double) -> [ScrollFrame] {
        carry += moved
        let whole = carry.rounded(.toNearestOrAwayFromZero)
        guard whole != 0 else { return [] }
        carry -= whole
        let first = !started
        started = true
        if state == .momentum { return [ScrollFrame(delta: Int32(whole), momentum: first ? 1 : 2)] }
        return [ScrollFrame(delta: Int32(whole), scroll: first ? 1 : 2)]
    }
}
