# Targets that don't require EMACSPEAK_DIR
list-devices:
	@swift scripts/list-audio-devices.swift

update-ogg:
	@echo "Updating OggDecoder to latest version..."
	@echo "Backing up Package.swift..."
	@cp Package.swift Package.swift.bak
	@echo "Switching to branch: main..."
	@sed -i.tmp 's/revision: "[^"]*"/branch: "main"/g' Package.swift && rm Package.swift.tmp
	@echo "Building to fetch latest..."
	@swift build > /dev/null 2>&1 || true
	@echo "Extracting new revision..."
	@NEW_REV=$$(grep -A 2 '"oggdecoder"' Package.resolved | grep revision | sed 's/.*"\([^"]*\)".*/\1/'); \
	if [ -n "$$NEW_REV" ]; then \
		echo "New revision: $$NEW_REV"; \
		echo "Updating Package.swift with new revision..."; \
		sed -i.tmp "s/branch: \"main\"/revision: \"$$NEW_REV\"/g" Package.swift && rm Package.swift.tmp; \
		echo "Done! OggDecoder updated to revision $$NEW_REV"; \
		echo "Running clean build with new revision..."; \
		swift package clean; \
		swift build; \
	else \
		echo "ERROR: Could not extract revision from Package.resolved"; \
		cp Package.swift.bak Package.swift; \
		exit 1; \
	fi
	@rm -f Package.swift.bak
	@echo "Update complete!"

# Set up EMACSPEAK paths if EMACSPEAK_DIR is set
ifdef EMACSPEAK_DIR
EMACSPEAK := $(EMACSPEAK_DIR)
SERVERS := $(EMACSPEAK)/servers
LISP := $(EMACSPEAK)/lisp
endif

# Helper to check EMACSPEAK_DIR for targets that need it
check-emacspeak:
ifndef EMACSPEAK_DIR
	$(error EMACSPEAK_DIR is not set)
endif

quick: debug

release: clean
	@swift build -c release 

debug:
	@swift build 

support-files: check-emacspeak
	@cp cloud-swiftmac $(SERVERS)/cloud-swiftmac
	@cp swiftmac-voices.el $(LISP)/swiftmac-voices.el
	@cp log-swiftmac $(SERVERS)/log-swiftmac
	@sed -i.bak '/swiftmac/d' $(SERVERS)/.servers && rm $(SERVERS)/.servers.bak
	@echo "swiftmac" >>  $(SERVERS)/.servers
	@echo "log-swiftmac" >> $(SERVERS)/.servers
	@echo "cloud-swiftmac" >> $(SERVERS)/.servers
	@sort -o $(SERVERS)/.servers $(SERVERS)/.servers

install: check-emacspeak release support-files backup-if-exists
	@rm -f $(SERVERS)/swiftmac
	@cp .build/release/swiftmac $(SERVERS)/swiftmac
	@cp -rf .build/release/ogg.framework $(SERVERS)/ogg.framework
	@cp -rf .build/release/vorbis.framework $(SERVERS)/vorbis.framework

install-debug: check-emacspeak debug support-files backup-if-exists
	@rm -f $(SERVERS)/swiftmac
	@cp .build/debug/swiftmac $(SERVERS)/swiftmac

backup-if-exists:
	@ if [ -f $(SERVERS)/swiftmac ]; then cp $(SERVERS)/swiftmac	\
	$(SERVERS)/swiftmac.last_version; fi

restore-from-backup:
	@if [ -f $(SERVERS)/swiftmac.last_version ]; then \
	    cp $(SERVERS)/swiftmac.last_version $(SERVERS)/swiftmac
	fi


tidy:
	@echo "=== Formatting Swift files ==="
	@if command -v swift-format >/dev/null 2>&1; then \
		for file in Package.swift Sources/SwiftMacPackage/*.swift; do \
			echo "Formatting $$file"; \
			swift-format $$file > temp && cp temp $$file; \
		done; \
		rm -f temp; \
	else \
		echo "WARNING: swift-format not found. Skipping Swift files."; \
		echo "Install with: brew install swift-format"; \
	fi
	@echo ""
	@echo "=== Formatting Shell scripts ==="
	@if command -v shfmt >/dev/null 2>&1; then \
		for file in *.sh; do \
			if [ -f "$$file" ]; then \
				echo "Formatting $$file"; \
				shfmt -w -i 2 -bn -ci -sr $$file; \
			fi; \
		done; \
	else \
		echo "WARNING: shfmt not found. Skipping shell scripts."; \
		echo "Install with: brew install shfmt"; \
	fi
	@echo ""
	@echo "=== Formatting Emacs Lisp files ==="
	@if command -v emacs >/dev/null 2>&1; then \
		for file in *.el; do \
			if [ -f "$$file" ]; then \
				echo "Formatting $$file"; \
				emacs --batch "$$file" \
					--eval '(setq-default indent-tabs-mode nil)' \
					--eval '(indent-region (point-min) (point-max))' \
					-f save-buffer 2>/dev/null; \
			fi; \
		done; \
	else \
		echo "WARNING: emacs not found. Skipping Emacs Lisp files."; \
	fi
	@echo ""
	@echo "=== Tidy complete! ==="

contribute: tidy
	@mkdir -p ~/Projects/others/emacspeak/servers/mac-swiftmac/
	@rm -rf ~/Projects/others/emacspeak/servers/mac-swiftmac/*
	@cp -Rvf * ~/Projects/others/emacspeak/servers/mac-swiftmac
	@cp -f .gitignore ~/Projects/others/emacspeak/servers/mac-swiftmac
	@cp -f .gitignore ~/Projects/others/emacspeak/servers/mac-swiftmac
	@cp -f Makefile.emacspeak ~/Projects/others/emacspeak/servers/mac-swiftmac/Makefile
	@cp -f Readme.emacspeak.org ~/Projects/others/emacspeak/servers/mac-swiftmac/Readme.org
	@cp -f cloud-swiftmac ~/Projects/others/emacspeak/servers/cloud-swiftmac
	@cp -f swiftmac-voices.el ~/Projects/others/emacspeak/lisp/
	@cp -f log-swiftmac ~/Projects/others/emacspeak/servers/log-swiftmac
	@rm -f ~/Projects/others/emacspeak/servers/Readme.emacspeak.org
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/Readme.emacspeak.org
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/get-emacspeak-path.sh
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/get-emacspeak-path.el
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/Package.resolved
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/cloud-swiftmac
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/Design.org
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/Goals.org
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/log-swiftmac
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/Makefile.emacspeak
	@rm -f ~/Projects/others/emacspeak/servers/mac-swiftmac/swiftmac-voices.el

clean:
	@swift package clean
	@rm -rf .build
	@rm -rf Package.resolved

super-nuke: clean
	@rm -rf ~/Library/Developer/Xcode/DerivedData
	@rm -rf ~/Library/Caches/org.swift.swiftpm
	@echo "Cache cleared and project rebuilt."

GITHUB_USER = robertmeta
REPO_NAME = swiftmac
LATEST_RELEASE_URL = https://api.github.com/repos/$(GITHUB_USER)/$(REPO_NAME)/releases/latest
DOWNLOAD_URL = $(shell curl -s $(LATEST_RELEASE_URL) | grep "browser_download_url" | cut -d '"' -f 4)

.PHONY: download_latest_release
download-latest-release:
	@echo "Fetching latest release download URL..."
	@echo "Latest release URL: $(DOWNLOAD_URL)"
	@echo "Downloading latest release..."
	@curl -L -o latest-release.tar.gz $(DOWNLOAD_URL)
	@echo "Download complete. Saved as latest-release.tar.gz"

install-binary: download-latest-release
	@tar -zxf latest-release.tar.gz
	@cp -rvf swiftmac/* $(EMACSPEAK)/servers
	@rm latest-release.tar.gz
	@rm -rf swiftmac/

test-emacs: debug
	@echo "Launching clean Emacs with debug build..."
	@DTK_PROGRAM="$(CURDIR)/.build/debug/swiftmac" emacs -Q -l "$(CURDIR)/minimal-emacspeak-init.el"

test-emacs-release: release
	@echo "Launching clean Emacs with release build..."
	@DTK_PROGRAM="$(CURDIR)/.build/release/swiftmac" emacs -Q -l "$(CURDIR)/minimal-emacspeak-init.el"
