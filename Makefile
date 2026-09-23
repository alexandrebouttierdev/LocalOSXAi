# Validation entry points. Every agent and contributor uses these targets so
# local runs and CI stay identical. See docs/code/testing.md.

PROJECT      := LocalOSXAi.xcodeproj
SCHEME       := LocalOSXAi
DESTINATION  := platform=macOS,arch=$(shell uname -m)
DERIVED_DATA := .build/DerivedData
XCODEBUILD   := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA)

.PHONY: generate build test test-live lint architecture docs check open clean

generate:
	xcodegen generate --quiet

build: generate
	$(XCODEBUILD) build -quiet

test: generate
	$(XCODEBUILD) test -quiet

# Opt-in tests against the local Ollama / LM Studio servers (see docs/code/testing.md).
test-live: generate
	TEST_RUNNER_LOCALOSXAI_LIVE_TESTS=1 $(XCODEBUILD) test -quiet -only-testing:LocalOSXAiTests/LiveProviderTests

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
