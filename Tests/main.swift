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

func run(_ glide: inout Glide, frames: Int) -> [Int32] {
    (0..<frames).map { _ in glide.step(dt: 1.0 / 60, stiffness: 14) }
}
var g = Glide()
g.add(100)
let steps = run(&g, frames: 120)
check("glide travels the exact distance without overshoot",
      ["\(steps.reduce(0, +))", "\(steps.allSatisfy { $0 >= 0 })", "\(g.isDone)"], ["100", "true", "true"])
g = Glide()
g.add(100)
_ = run(&g, frames: 5)
g.add(-40)
check("glide reverses immediately", ["\(run(&g, frames: 120).reduce(0, +))"], ["-40"])

exit(failures == 0 ? 0 : 1)
