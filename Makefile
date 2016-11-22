PREFIX?=/usr/local
BUILD_TOOL?=xcodebuild
BINARIES_FOLDER=/usr/local/bin

EXECUTABLE_NAME = swiftplate
XCODEFLAGS=-project 'SwiftPlate.xcodeproj'

SWIFTPLATE_EXECUTABLE=./build/Release/$(EXECUTABLE_NAME)

SWIFT_COMMAND=/usr/bin/swift
SWIFT_BUILD_COMMAND=$(SWIFT_COMMAND) build
SWIFT_TEST_COMMAND=$(SWIFT_COMMAND) test

install:
	xcodebuild $(XCODEFLAGS)
	mkdir -p $(PREFIX)/bin
	cp -f $(SWIFTPLATE_EXECUTABLE) $(PREFIX)/bin

uninstall:
	rm -f $(PREFIX)/bin/$(EXECUTABLE_NAME)