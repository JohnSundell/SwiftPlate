PREFIX?=/usr/local
BUILD_TOOL?=xcodebuild
BINARIES_FOLDER=/usr/local/bin

XCODEFLAGS=-project 'SwiftPlate.xcodeproj'

SWIFTPLATE_EXECUTABLE=./build/Release/swiftplate

SWIFT_COMMAND=/usr/bin/swift
SWIFT_BUILD_COMMAND=$(SWIFT_COMMAND) build
SWIFT_TEST_COMMAND=$(SWIFT_COMMAND) test

install:
	xcodebuild $(XCODEFLAGS)
	mkdir -p "$(PREFIX)/bin"
	cp -f "$(SWIFTPLATE_EXECUTABLE)" "$(PREFIX)/bin"

uninstall:
	rm -f "$(BINARIES_FOLDER)/swiftlint"