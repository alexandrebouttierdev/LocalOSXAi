# Validation entry points. Every agent and contributor uses these targets so
# local runs and CI stay identical. See docs/code/testing.md.

PROJECT      := LocalOSXAi.xcodeproj
SCHEME       := LocalOSXAi
DESTINATION  := platform=macOS,arch=$(shell uname -m)
DERIVED_DATA := .build/DerivedData
XCODEBUILD   := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA)

.PHONY: generate build test test-live ui-snapshots lint architecture docs check open clean

generate:
	xcodegen generate --quiet

build: generate
	$(XCODEBUILD) build -quiet

test: generate
	$(XCODEBUILD) test -quiet

# Opt-in tests against the local Ollama / LM Studio servers (see docs/code/testing.md).
test-live: generate
	TEST_RUNNER_LOCALOSXAI_LIVE_TESTS=1 $(XCODEBUILD) test -quiet -only-testing:LocalOSXAiTests/LiveProviderTests

# Launches the simulated app and saves screenshots of its main screens to
# $(SNAPSHOT_DIR) for visual review. Takes over the screen for a minute.
# The demo project lives outside ~/Documents so macOS never asks for folder
# access in the middle of the run. The screenshots are test attachments,
# exported from the result bundle (the UI test runner is sandboxed).
# The app is built outside the repository too: an app running from ~/Documents
# triggers the same prompt.
SNAPSHOT_DIR ?= .build/ui-snapshots
DEMO_PROJECT := /tmp/localosxai-demo
SNAPSHOT_BUILD := /tmp/localosxai-ui-snapshots
ui-snapshots: generate
	rm -rf '$(SNAPSHOT_DIR)' '$(DEMO_PROJECT)' '$(SNAPSHOT_BUILD)/result.xcresult'
	./scripts/make-demo-project.sh '$(DEMO_PROJECT)'
	TEST_RUNNER_DEMO_PROJECT='$(DEMO_PROJECT)' \
		xcodebuild -project $(PROJECT) -scheme LocalOSXAiUISnapshots -destination '$(DESTINATION)' \
		-derivedDataPath '$(SNAPSHOT_BUILD)' -resultBundlePath '$(SNAPSHOT_BUILD)/result.xcresult' test -quiet
	./scripts/export-ui-snapshots.sh '$(SNAPSHOT_BUILD)/result.xcresult' '$(SNAPSHOT_DIR)'

lint:
	swiftlint lint --strict --quiet

architecture:
	./scripts/check-architecture.sh

docs:
	./scripts/check-docs.sh

# Full validation gate: run before considering any change done.
check: generate lint architecture docs
	$(XCODEBUILD) build -quiet
	$(XCODEBUILD) test -quiet

open: generate
	open $(PROJECT)

clean:
	rm -rf .build $(PROJECT)
