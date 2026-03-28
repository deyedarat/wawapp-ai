.PHONY: sync-hard analyze debug release pack-lib help

# Default target
help:
	@echo "Available targets:"
	@echo "  sync-hard  - Hard sync with origin/main"
	@echo "  analyze    - Run flutter analyze"
	@echo "  debug      - Run app in debug mode"
	@echo "  release    - Build release APK"
	@echo "  pack-lib   - Pack lib folder for distribution"

sync-hard:
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File tool/sync/sync_hard.ps1
else
	@chmod +x tool/sync/sync_hard.sh && ./tool/sync/sync_hard.sh
endif

analyze:
	@flutter analyze

debug:
	@flutter run --debug --dart-define=MAPS_API_KEY=AIzaSyBkeDIcXg0M-zfXogKtHfyZWWdNb916vjU

release:
	@flutter build apk --release --dart-define=MAPS_API_KEY=AIzaSyBkeDIcXg0M-zfXogKtHfyZWWdNb916vjU

pack-lib:
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File tool/pack/pack_lib.ps1
else
	@chmod +x tool/pack/pack_lib.sh && ./tool/pack/pack_lib.sh
endif