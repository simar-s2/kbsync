// Prints the built-in display's brightness (0 to 1), sets it, or eases it to
// a new level over some seconds. Only the demo and filming scripts use this;
// kbsync itself never changes the display.
//
//   set-display-brightness              print the current level
//   set-display-brightness 0.4          jump to 40%
//   set-display-brightness 0 3          ease down to 0% over 3 seconds
import CoreGraphics
import Foundation

let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
guard let handle = dlopen(path, RTLD_NOW),
      let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
      let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
else {
    fatalError("DisplayServices is unavailable")
}
typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
let getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
let setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)

let display = CGMainDisplayID()
var current: Float = 0
_ = getBrightness(display, &current)

let arguments = CommandLine.arguments.dropFirst()
guard let targetText = arguments.first, let target = Float(targetText) else {
    print(current)
    exit(0)
}
let seconds = arguments.dropFirst().first.flatMap(Double.init) ?? 0

// 60 steps a second with ease-in-out, so a fade looks like a hand on a slider.
let steps = max(1, Int(seconds * 60))
for step in 1...steps {
    let t = Double(step) / Double(steps)
    let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    guard setBrightness(display, current + (target - current) * Float(eased)) == 0 else { exit(1) }
    if steps > 1 { usleep(useconds_t(seconds / Double(steps) * 1_000_000)) }
}
