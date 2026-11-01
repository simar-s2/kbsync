PREFIX ?= /usr/local
BIN := .build/release/kbsync

# With only the Command Line Tools installed (no Xcode), SwiftPM doesn't find
# the Swift Testing framework on its own.
CLT_DEVELOPER := /Library/Developer/CommandLineTools/Library/Developer
ifneq ($(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)),)
TEST_FLAGS := -Xswiftc -F$(CLT_DEVELOPER)/Frameworks -Xlinker -F$(CLT_DEVELOPER)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEVELOPER)/Frameworks -Xlinker -rpath -Xlinker $(CLT_DEVELOPER)/usr/lib
endif

.PHONY: build test install uninstall demo film gif clean

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

# Doesn't build, so `sudo make install` never leaves root-owned files in .build.
install:
	@test -x $(BIN) || { echo "run 'make build' first"; exit 1; }
	install -d $(PREFIX)/bin
	install -m 755 $(BIN) $(PREFIX)/bin/kbsync

uninstall:
	rm -f $(PREFIX)/bin/kbsync

DISPLAY_TOOL := .build/set-display-brightness

$(DISPLAY_TOOL): scripts/set-display-brightness.swift
	@mkdir -p .build
	swiftc -O $< -o $@

# Records docs/images/demo.gif. It really changes the display brightness for
# a few seconds and puts it back afterwards.
demo: build $(DISPLAY_TOOL)
	vhs docs/tapes/demo.tape

# A hands-free routine to film: the screen fades to black and back while
# kbsync (which must already be running) moves the keyboard with it.
film: $(DISPLAY_TOOL)
	scripts/film.sh

# Turns a recording into docs/images/hero.gif and hero.mp4:
#   make gif VIDEO=~/Movies/kbsync.mov START=3 DURATION=12
gif:
	@test -n "$(VIDEO)" || { echo "usage: make gif VIDEO=path/to/video [START=s] [DURATION=s]"; exit 1; }
	scripts/video-to-gif.sh "$(VIDEO)" $(or $(START),0) $(or $(DURATION),12)

clean:
	rm -rf .build
