PREFIX ?= /usr/local
BIN := .build/release/kbsync
VERSION := $(shell sed -n 's/^public let version = "\(.*\)"/\1/p' Sources/KBSyncCore/Arguments.swift)
APP := .build/kbsync.app

# With only the Command Line Tools installed (no Xcode), SwiftPM doesn't find
# the Swift Testing framework on its own.
CLT_DEVELOPER := /Library/Developer/CommandLineTools/Library/Developer
ifneq ($(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)),)
TEST_FLAGS := -Xswiftc -F$(CLT_DEVELOPER)/Frameworks -Xlinker -F$(CLT_DEVELOPER)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEVELOPER)/Frameworks -Xlinker -rpath -Xlinker $(CLT_DEVELOPER)/usr/lib
endif

.PHONY: build test install uninstall app install-app dist demo film gif clean

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

# The menu bar app: SwiftPM builds the executable, this wraps it in a bundle.
app:
	swift build -c release --product KBSyncApp
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/KBSyncApp $(APP)/Contents/MacOS/kbsync
	cp App/Info.plist $(APP)/Contents/Info.plist
	plutil -replace CFBundleShortVersionString -string $(VERSION) $(APP)/Contents/Info.plist
	plutil -replace CFBundleVersion -string $(VERSION) $(APP)/Contents/Info.plist
	cp App/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(APP)

install-app: app
	rm -rf /Applications/kbsync.app
	cp -R $(APP) /Applications/kbsync.app

# The zip attached to a GitHub release, which the Homebrew cask downloads.
dist: app
	rm -rf .build/dist
	mkdir -p .build/dist
	ditto -c -k --keepParent $(APP) .build/dist/kbsync-$(VERSION).zip
	shasum -a 256 .build/dist/kbsync-$(VERSION).zip

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

# Turns a recording into docs/images/hero.gif and hero.mp4 (HDR is converted):
#   make gif VIDEO=~/Movies/kbsync.mov START=3 DURATION=12 CROP=1080:1300:0:340
gif:
	@test -n "$(VIDEO)" || { echo "usage: make gif VIDEO=path/to/video [START=s] [DURATION=s]"; exit 1; }
	CROP=$(CROP) scripts/video-to-gif.sh "$(VIDEO)" $(or $(START),0) $(or $(DURATION),12)

clean:
	rm -rf .build
