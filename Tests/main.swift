import Foundation

var failures = 0
func check(_ name: String, _ got: [String], _ want: [String]) {
    if got != want { failures += 1; print("FAIL \(name): got \(got), want \(want)") }
    else { print("ok   \(name)") }
}

final class Rig {
    let engine = ButtonEngine()
    var log: [String] = []
    var timers: [(delay: Double, block: () -> Void, cancelled: Bool)] = []
    init(_ cfg: ButtonConfig) {
        engine.config = { [3: cfg] }
        engine.perform = { [unowned self] in log.append($0.action.rawValue) }
        engine.replayClick = { [unowned self] in log.append("replay\($0)") }
        engine.dragScroll = { [unowned self] _, _ in log.append("dragScroll") }
        engine.wheelAction = { [unowned self] mode, d in log.append("\(mode.rawValue)\(d)") }
        engine.schedule = { [unowned self] delay, block in
            let i = timers.count
            timers.append((delay, block, false))
            return { [unowned self] in timers[i].cancelled = true }
        }
    }
    func fire() {
        for i in timers.indices where !timers[i].cancelled {
            timers[i].cancelled = true
            timers[i].block()
        }
    }
}

let full = ButtonConfig(click: Binding(action: .back), doubleClick: Binding(action: .copy),
                        hold: Binding(action: .paste), drag: .spaces, wheel: .zoom)

var r = Rig(ButtonConfig(click: Binding(action: .back)))
_ = r.engine.down(3); _ = r.engine.up(3)
check("single click is immediate", r.log, ["back"])

r = Rig(full)
_ = r.engine.down(3); _ = r.engine.up(3); r.fire()
check("click waits for double click", r.log, ["back"])

r = Rig(full)
_ = r.engine.down(3); _ = r.engine.up(3); _ = r.engine.down(3); _ = r.engine.up(3); r.fire()
check("double click", r.log, ["copy"])

r = Rig(full)
_ = r.engine.down(3); r.fire(); _ = r.engine.up(3)
check("hold", r.log, ["paste"])

r = Rig(full)
_ = r.engine.down(3); r.engine.moved(dx: 100, dy: 5); r.engine.moved(dx: 100, dy: 0); r.fire(); _ = r.engine.up(3)
check("drag fires once, no click or hold", r.log, ["spaceLeft"])

r = Rig(full)
_ = r.engine.down(3); r.engine.moved(dx: 0, dy: -90); _ = r.engine.up(3)
check("drag up", r.log, ["missionControl"])

r = Rig(full)
_ = r.engine.down(3); let claimed = r.engine.wheel(1); r.fire(); _ = r.engine.up(3)
check("wheel while held", r.log + ["\(claimed)"], ["zoom1", "true"])

r = Rig(ButtonConfig(wheel: .zoom))
_ = r.engine.down(3); _ = r.engine.up(3)
check("unmapped click is replayed", r.log, ["replay3"])

r = Rig(ButtonConfig())
check("unconfigured button passes through", ["\(r.engine.down(3))", "\(r.engine.up(3))", "\(r.engine.wheel(1))"],
      ["false", "false", "false"])

func run(_ glide: inout Glide, frames: Int = 600) -> [ScrollFrame] {
    (0..<frames).flatMap { _ in glide.step(dt: 1.0 / 60) }
}
func total(_ f: [ScrollFrame]) -> Int { f.reduce(0) { $0 + Int($1.delta) } }
/// Phase events collapsed to their order, e.g. B C E b c e.
func shape(_ frames: [ScrollFrame]) -> String {
    var out = ""
    for f in frames {
        let c = f.scroll != 0 ? [1: "B", 2: "C", 4: "E"][Int(f.scroll)]! : [1: "b", 2: "c", 3: "e"][Int(f.momentum)]!
        if !out.hasSuffix(c) { out += c }
    }
    return out
}

var g = Glide()
_ = g.add(100, smoothness: 0.8, coasts: false)
var f = run(&g)
check("precise glide travels the exact distance", ["\(total(f))", shape(f), "\(g.isDone)"], ["100", "BCE", "true"])

g = Glide()
_ = g.add(100, smoothness: 0.8, coasts: true)
f = run(&g)
check("gesture then momentum, never backwards",
      [shape(f), "\(f.allSatisfy { $0.delta >= 0 })", "\(total(f) >= 90)", "\(g.isDone)"], ["BCEbce", "true", "true", "true"])

g = Glide()
_ = g.add(300, smoothness: 0.8, coasts: true)
_ = run(&g, frames: 15)
let caught = g.add(-50, smoothness: 0.8, coasts: true)
check("opposite tick catches a coasting page", [shape(caught), "\(total(caught))", "\(g.isDone)"], ["e", "0", "true"])

g = Glide()
_ = g.add(300, smoothness: 0.8, coasts: true)
_ = run(&g, frames: 15)
let again = g.add(50, smoothness: 0.8, coasts: true)
f = run(&g)
check("same direction tick continues without overshoot",
      [shape(again), "\(f.allSatisfy { $0.delta >= 0 })", shape(f)], ["e", "true", "BCEbce"])

g = Glide()
_ = g.add(300, smoothness: 0.8, coasts: true)
_ = run(&g, frames: 3)
let turn = g.add(-100, smoothness: 0.8, coasts: true)
f = run(&g)
check("reversing mid-gesture turns immediately", [shape(turn), "\(f.allSatisfy { $0.delta <= 0 })"], ["E", "true"])

let old = Config.load(Data(#"{"enabled":true,"speed":2}"#.utf8))
check("old settings survive new options",
      ["\(old.enabled)", "\(old.speed)", "\(old.trackpadSimulation)"], ["true", "2.0", "true"])

exit(failures == 0 ? 0 : 1)
