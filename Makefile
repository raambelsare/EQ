APP_NAME=MacEQ
BUILD_DIR=.build/release
APP_BUNDLE=$(APP_NAME).app
CONTENTS=$(APP_BUNDLE)/Contents
MACOS=$(CONTENTS)/MacOS
RESOURCES=$(CONTENTS)/Resources

all: test build bundle sign

test:
	swift test -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib

build:
	swift build -c release

bundle:
	mkdir -p $(MACOS)
	mkdir -p $(RESOURCES)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS)/
	cp Info.plist $(CONTENTS)/

sign:
	codesign --force --deep --sign "-" --entitlements MacEQ.entitlements $(APP_BUNDLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
