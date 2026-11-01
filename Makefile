PREFIX ?= /usr/local
BIN := .build/release/kbsync

# With only the Command Line Tools installed (no Xcode), SwiftPM doesn't find
# the Swift Testing framework on its own.
CLT_DEVELOPER := /Library/Developer/CommandLineTools/Library/Developer
ifneq ($(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)),)
TEST_FLAGS := -Xswiftc -F$(CLT_DEVELOPER)/Frameworks -Xlinker -F$(CLT_DEVELOPER)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEVELOPER)/Frameworks -Xlinker -rpath -Xlinker $(CLT_DEVELOPER)/usr/lib
endif

.PHONY: build test install uninstall demo clean

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

# Records docs/images/demo.gif. It really changes the display brightness for
# a few seconds and puts it back afterwards.
demo: build
	swiftc -O scripts/set-display-brightness.swift -o .build/set-display-brightness
	vhs docs/tapes/demo.tape

clean:
	rm -rf .build
