APP_BUNDLE := dist/MacClipy.app
BUNDLE_ID ?= jp.techguide.macclipy
BUILD_CONFIG ?= release
APP_VERSION ?= 0.1.0
BUILD_NUMBER ?= 1
DEVELOPMENT_CRASH_MODAL_ENABLED ?= 0

.PHONY: build-app check format package-release reapply-local run

build-app:
	@BUNDLE_ID="$(BUNDLE_ID)" BUILD_CONFIG="$(BUILD_CONFIG)" APP_VERSION="$(APP_VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" DEVELOPMENT_CRASH_MODAL_ENABLED="$(DEVELOPMENT_CRASH_MODAL_ENABLED)" scripts/build-app.sh

check:
	@scripts/check.sh

format:
	@scripts/format.sh

package-release:
	@APP_VERSION="$(APP_VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" scripts/package-release.sh

reapply-local:
	@BUNDLE_ID="$(BUNDLE_ID)" scripts/app-lifecycle.swift quit-and-wait
	@BUNDLE_ID="$(BUNDLE_ID)" BUILD_CONFIG="$(BUILD_CONFIG)" APP_VERSION="$(APP_VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" DEVELOPMENT_CRASH_MODAL_ENABLED="$(DEVELOPMENT_CRASH_MODAL_ENABLED)" scripts/build-app.sh
	@open "$(APP_BUNDLE)"
	@BUNDLE_ID="$(BUNDLE_ID)" scripts/app-lifecycle.swift wait-running

run: BUILD_CONFIG = debug
run: DEVELOPMENT_CRASH_MODAL_ENABLED = 1
run: reapply-local
