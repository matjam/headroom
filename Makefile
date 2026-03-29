.PHONY: generate build run clean check-deps dmg release

.DEFAULT_GOAL := build

# Load local overrides if they exist
-include .env

# Required tools
XCODEGEN := $(shell command -v xcodegen 2>/dev/null)
XCODEBUILD := $(shell command -v xcodebuild 2>/dev/null)

# Build output
APP_NAME := Headroom
DMG_NAME := $(APP_NAME).dmg
DMG_DIR := dist
DMG_STAGING := $(DMG_DIR)/staging

# Derive version from git tag (e.g. v1.0.4 -> 1.0.4)
GIT_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
VERSION := $(if $(GIT_VERSION),$(GIT_VERSION),0.0.0-dev)
VERSION_ARGS := MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(VERSION) GIT_COMMIT_SHA=$(GIT_SHA)

check-deps:
ifndef XCODEGEN
	$(error xcodegen is not installed. Install with: brew install xcodegen)
endif
ifndef XCODEBUILD
	$(error xcodebuild is not installed. Install Xcode from the App Store and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer)
endif
	@xcodebuild -version >/dev/null 2>&1 || (echo "Error: Xcode command line tools not configured. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" && exit 1)

generate: check-deps
	DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" xcodegen generate

# Signing configuration:
#   - No DEVELOPMENT_TEAM: ad-hoc signing (CI, contributors)
#   - DEVELOPMENT_TEAM set: Apple Development for debug, Developer ID for release
ifdef DEVELOPMENT_TEAM
DEBUG_SIGNING := CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development"
RELEASE_SIGNING := CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
else
DEBUG_SIGNING := CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
RELEASE_SIGNING := CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
endif

build: generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug $(DEBUG_SIGNING) $(VERSION_ARGS) build

release: generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release $(RELEASE_SIGNING) $(VERSION_ARGS) build

dmg: release
	@echo "Creating $(DMG_NAME) v$(VERSION)..."
	@# Clean previous staging
	@rm -rf $(DMG_DIR)
	@mkdir -p $(DMG_STAGING)
	@# Find and copy the Release .app bundle
	@APP_PATH=$$(xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
	if [ ! -d "$$APP_PATH/$(APP_NAME).app" ]; then \
		echo "Error: $(APP_NAME).app not found at $$APP_PATH"; \
		exit 1; \
	fi; \
	cp -R "$$APP_PATH/$(APP_NAME).app" $(DMG_STAGING)/
ifdef DEVELOPMENT_TEAM
	@# Re-sign embedded Sparkle components with Developer ID, preserving entitlements
	@echo "Re-signing embedded binaries with Developer ID..."
	@# Sign XPC services (innermost first)
	@for xpc in $(DMG_STAGING)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/*.xpc; do \
		[ -d "$$xpc" ] && codesign --force --options runtime --timestamp --sign "Developer ID Application" --preserve-metadata=entitlements "$$xpc" && echo "  Signed: $$(basename $$xpc)"; \
	done
	@# Sign Updater.app
	@if [ -d "$(DMG_STAGING)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" ]; then \
		codesign --force --options runtime --timestamp --sign "Developer ID Application" --preserve-metadata=entitlements "$(DMG_STAGING)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" && echo "  Signed: Updater.app"; \
	fi
	@# Sign Autoupdate binary
	@if [ -f "$(DMG_STAGING)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" ]; then \
		codesign --force --options runtime --timestamp --sign "Developer ID Application" "$(DMG_STAGING)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" && echo "  Signed: Autoupdate"; \
	fi
	@# Sign Sparkle framework
	@codesign --force --options runtime --timestamp --sign "Developer ID Application" "$(DMG_STAGING)/$(APP_NAME).app/Contents/Frameworks/Sparkle.framework"
	@echo "  Signed: Sparkle.framework"
	@# Sign the main app (not --deep, just the top level)
	@codesign --force --options runtime --timestamp --entitlements Headroom/Headroom.entitlements --sign "Developer ID Application" $(DMG_STAGING)/$(APP_NAME).app
	@echo "  Signed: $(APP_NAME).app"
	@echo "Verifying signature..."
	@codesign --verify --deep --strict $(DMG_STAGING)/$(APP_NAME).app
endif
	@# Create symlink to /Applications
	@ln -s /Applications $(DMG_STAGING)/Applications
	@# Create the DMG
	@hdiutil create -volname "$(APP_NAME) $(VERSION)" \
		-srcfolder $(DMG_STAGING) \
		-ov -format UDZO \
		$(DMG_DIR)/$(DMG_NAME) \
		>/dev/null
	@# Clean staging
	@rm -rf $(DMG_STAGING)
	@echo "Created $(DMG_DIR)/$(DMG_NAME)"

run: build
	@echo "Launching $(APP_NAME)..."
	@pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	@open "$$(xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}')/$(APP_NAME).app"

clean:
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) clean 2>/dev/null || true
	rm -rf $(APP_NAME).xcodeproj $(DMG_DIR)
