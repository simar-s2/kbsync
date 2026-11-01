// Sets the built-in display's brightness (0 to 1), or prints it when run
// without an argument. Only the demo recording uses this; kbsync itself
// never changes the display.
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
if CommandLine.arguments.count > 1, let value = Float(CommandLine.arguments[1]) {
    exit(setBrightness(display, value) == 0 ? 0 : 1)
}
var value: Float = 0
_ = getBrightness(display, &value)
print(value)
