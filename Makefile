SHELL := /bin/bash

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOOLS := $(ROOT)/Tools

XCODEGEN_VERSION := 2.46.0
SWIFTLINT_VERSION := 0.65.1

# UI tests launch the app, so they need a named simulator. Override with `make ui-test UI_TEST_DESTINATION=...`.
UI_TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17

.PHONY: bootstrap generate lint format test unit-test ui-test

bootstrap:
	mkdir -p "$(TOOLS)/downloads"
	if [ ! -x "$(TOOLS)/xcodegen/bin/xcodegen" ]; then \
		curl -fsSL -o "$(TOOLS)/downloads/xcodegen.zip" \
			"https://github.com/yonaskolb/XcodeGen/releases/download/$(XCODEGEN_VERSION)/xcodegen.zip"; \
		rm -rf "$(TOOLS)/xcodegen"; \
		unzip -q "$(TOOLS)/downloads/xcodegen.zip" -d "$(TOOLS)"; \
	fi
	if [ ! -x "$(TOOLS)/swiftlint" ]; then \
		curl -fsSL -o "$(TOOLS)/downloads/swiftlint.zip" \
			"https://github.com/realm/SwiftLint/releases/download/$(SWIFTLINT_VERSION)/portable_swiftlint.zip"; \
		unzip -q -o "$(TOOLS)/downloads/swiftlint.zip" -d "$(TOOLS)"; \
		chmod +x "$(TOOLS)/swiftlint"; \
	fi
	test -x "$(TOOLS)/xcodegen/bin/xcodegen"
	test -x "$(TOOLS)/swiftlint"

generate: bootstrap
	"$(TOOLS)/xcodegen/bin/xcodegen" generate --spec "$(ROOT)/project.yml" --project "$(ROOT)"

lint: bootstrap
	"$(TOOLS)/swiftlint" lint --strict --config "$(ROOT)/.swiftlint.yml" "$(ROOT)"
	xcrun swift-format lint --strict --recursive --configuration "$(ROOT)/.swift-format" \
		"$(ROOT)/App" "$(ROOT)/Packages/JobTrackerKit/Sources" "$(ROOT)/Packages/JobTrackerKit/Tests"

format:
	xcrun swift-format format --in-place --recursive --configuration "$(ROOT)/.swift-format" \
		"$(ROOT)/App" "$(ROOT)/Packages/JobTrackerKit/Sources" "$(ROOT)/Packages/JobTrackerKit/Tests"

test: unit-test

unit-test:
	swift test --package-path "$(ROOT)/Packages/JobTrackerKit" -Xswiftc -warnings-as-errors

ui-test: generate
	xcodebuild \
		-project "$(ROOT)/JobTracker.xcodeproj" \
		-scheme JobTracker \
		-destination "$(UI_TEST_DESTINATION)" \
		-derivedDataPath "$(ROOT)/DerivedData" \
		CODE_SIGNING_ALLOWED=NO \
		test
