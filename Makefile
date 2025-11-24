ifndef EMACSPEAK_DIR
$(error EMACSPEAK_DIR is not set)
endif

EMACSPEAK := $(EMACSPEAK_DIR)
SERVERS := $(EMACSPEAK)/servers
LISP := $(EMACSPEAK)/lisp

quick: debug

release: clean
	@swift build -c release 

debug:
	@swift build 

support-files:
	@cp cloud-swiftmac $(SERVERS)/cloud-swiftmac
	@cp swiftmac-voices.el $(LISP)/swiftmac-voices.el
	@cp log-swiftmac $(SERVERS)/log-swiftmac
	@sed -i '' '/swiftmac/d' $(SERVERS)/.servers
	@echo "swiftmac" >>  $(SERVERS)/.servers
	@echo "log-swiftmac" >> $(SERVERS)/.servers
	@echo "cloud-swiftmac" >> $(SERVERS)/.servers
	@sort -o $(SERVERS)/.servers $(SERVERS)/.servers

install: release support-files backup-if-exists
	@rm -f $(SERVERS)/swiftmac
	@cp .build/release/swiftmac $(SERVERS)/swiftmac
	@cp -rf .build/release/ogg.framework $(SERVERS)/ogg.framework
	@cp -rf .build/release/vorbis.framework $(SERVERS)/vorbis.framework

install-debug: debug support-files backup-if-exists
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
	@swift-format Package.swift > temp
	@cp temp Package.swift
	@swift-format Sources/SwiftMacPackage/logger.swift > temp
	@cp temp Sources/SwiftMacPackage/logger.swift 
	@swift-format Sources/SwiftMacPackage/statestore.swift > temp
	@cp temp Sources/SwiftMacPackage/statestore.swift 
	@swift-format Sources/SwiftMacPackage/main.swift > temp
	@cp temp Sources/SwiftMacPackage/main.swift 
	@swift-format Sources/SwiftMacPackage/toneplayer.swift > temp
	@cp temp Sources/SwiftMacPackage/toneplayer.swift 
	@rm temp

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
