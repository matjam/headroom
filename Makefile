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
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Headroom/Info.plist 2>/dev/null || echo "1.0")

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

build: generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug build

release: generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release build

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
