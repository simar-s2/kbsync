# Design notes

What I found while probing the private brightness APIs on a MacBook Pro (M1 Pro, macOS 26.6).

## No public API

Neither the display brightness nor the keyboard backlight has a public API on Apple Silicon. kbsync loads two private frameworks at runtime with `dlopen`:

- **DisplayServices:** `DisplayServicesGetBrightness` and `DisplayServicesRegisterForBrightnessChangeNotifications`. The notification is system wide: one process receives it when any other process changes the brightness.
- **CoreBrightness:** `KeyboardBrightnessClient`, called through an `@objc` protocol. Every selector is checked with `responds(to:)` first, so a changed macOS gives a clear error instead of a crash.

## Why not poll

Polling has to run ten or more times a second to feel instant, to watch a value that changes a few times an hour. The notification costs nothing until the brightness changes.

## Idle-off

While macOS holds the backlight off after inactivity, `brightnessForKeyboard:` reports 0, and writes are accepted but don't light the keyboard. kbsync skips writes while `isBacklightDimmedOnKeyboard:` is true and re-syncs when the `KeyboardBacklightIdleDimActive` or `KeyboardBacklightSuppressed` notifications clear.

## Suppressed isn't asleep

CoreBrightness also reports the backlight as suppressed whenever its level is 0%, and the next write lights it straight back up. kbsync originally treated suppressed as asleep, so once the screen hit 0% the keyboard stayed dark for good. Now only the idle flag holds writes back.

## The light sensor

With "Adjust keyboard brightness in low light" on, the sensor moves the keyboard by itself; I watched it drift from 24.5% to 24.0% with nothing else touching it. kbsync turns the sensor off while it runs and back on when it exits. The display's own auto-brightness is untouched, so the keyboard still follows the room, through the display.

## Fade units

`setBrightness:fadeSpeed:commit:forKeyboard:` is undocumented. Reading the backlight's PWM duty cycle from the IORegistry during a `fadeSpeed: 2000` call showed an even 2.0 s ramp, so the unit is milliseconds.

## Bursts

The display notification arrives on a background thread, sometimes hundreds a second (a held key, a dragged slider). Each one bumps a GCD data-add source, which merges any burst into one handler call on the main queue. Before that, a 5,000-change burst queued about 2,500 callbacks; now it queues a handful.

## Testing

The curve, argument parsing, sync rules and launch agent plist live in `KBSyncCore` and are unit tested against a fake display and keyboard. The private-framework bridges were tested on hardware, down to the PWM register. The stress test ran 20,000 brightness changes: memory stayed flat and `leaks` reported 0 bytes.
