Output docs/images/demo.gif
Set Shell "bash"
Set FontSize 16
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 30ms
Set Height 600
Set Width 1300
Env BASH_SILENCE_DEPRECATION_WARNING "1"

# Off camera: put the build on PATH, and schedule a sweep of the display
# brightness (standing in for someone pressing the brightness keys) that
# starts once kbsync is running and ends where it began.
Hide
Type 'export PATH="$PWD/.build/release:$PATH" PS1="\[\e[1;35m\]kbsync\[\e[0m\] $ "' Enter
Type 'set_display=.build/set-display-brightness; start=$($set_display)' Enter
Type '( (sleep 6.5; for v in 0.40 0.65 0.90 0.55 0.25 $start; do $set_display $v; sleep 1.3; done) >/dev/null 2>&1 & ); clear' Enter
Sleep 500ms
Show

Type "kbsync status" Sleep 300ms Enter
Sleep 3s
Type "kbsync run --verbose" Sleep 300ms Enter
Sleep 10s
Ctrl+C
Sleep 3s
