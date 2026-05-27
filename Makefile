APP_BUNDLE := dist/MacClipy.app
BUNDLE_ID := com.local.MacClipy
BUILD_CONFIG ?= release
DEVELOPMENT_CRASH_MODAL_ENABLED ?= 0

.PHONY: build-app check format reapply-local run

build-app:
	@BUILD_CONFIG="$(BUILD_CONFIG)" DEVELOPMENT_CRASH_MODAL_ENABLED="$(DEVELOPMENT_CRASH_MODAL_ENABLED)" scripts/build-app.sh

check:
	@scripts/check.sh

format:
	@scripts/format.sh

reapply-local: build-app
	@osascript -e 'if application id "$(BUNDLE_ID)" is running then tell application id "$(BUNDLE_ID)" to quit'
	@sleep 1
	@open "$(APP_BUNDLE)"
	@sleep 1
	@osascript -e 'application id "$(BUNDLE_ID)" is running'

run: BUILD_CONFIG = debug
run: DEVELOPMENT_CRASH_MODAL_ENABLED = 1
run: reapply-local
