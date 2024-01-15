EMACSPEAK := $(shell ./get-emacspeak-path.sh)
SERVERS := $(EMACSPEAK)/servers

debug:
	swift build

release:
	swift build -c release

fat-release:
	swift build -c release --triple arm64-apple-macosx
	swift build -c release --triple x86_64-apple-macosx
	mkdir -p universal
	lipo -create .build/arm64-apple-macosx/release/swiftmac .build/x86_64-apple-macosx/release/swiftmac -output universal/swiftmac
	lipo -info universal/swiftmac

support_files:
	cp cloud-swiftmac $(SERVERS)/cloud-swiftmac
	cp log-swiftmac $(SERVERS)/log-swiftmac
	sed -i '' '/swiftmac/d' $(SERVERS)/.servers
	echo "swiftmac" >>  $(SERVERS)/.servers
	echo "log-swiftmac" >>  $(SERVERS)/.servers
	echo "cloud-swiftmac" >> $(SERVERS)/.servers
	sort -o $(SERVERS)/.servers $(SERVERS)/.servers

install: release support_files backup_if_exists
	cp .build/release/swiftmac $(SERVERS)/swiftmac

install-debug: debug support_files backup_if_exists
	cp .build/debug/swiftmac $(SERVERS)/swiftmac

backup_if_exists:
	if [ -f $(SERVERS)/swiftmac ]; then \
	    cp $(SERVERS)/swiftmac $(SERVERS)/swiftmac.last_version; \
	fi

install-binary: support_files backup_if_exists
	curl -L https://github.com/robertmeta/swiftmac/releases/download/latest/swiftmac --output $(SERVERS)/swiftmac
	chmod +x $(SERVERS)/swiftmac

tidy:
	swift-format Package.swift > temp
	cp temp Package.swift
	swift-format Sources/SwiftMacPackage/logger.swift > temp
	cp temp Sources/SwiftMacPackage/logger.swift 
	swift-format Sources/SwiftMacPackage/main.swift > temp
	cp temp Sources/SwiftMacPackage/main.swift 
	swift-format Sources/SwiftMacPackage/playpuretone.swift > temp
	cp temp Sources/SwiftMacPackage/playpuretone.swift 
	swift-format Sources/SwiftMacPackage/statestore.swift > temp
	cp temp Sources/SwiftMacPackage/statestore.swift 
	rm temp

contribute: tidy
	cp -Rvf Sources ~/Projects/others/emacspeak/servers/mac-swiftmac
	cp -f Makefile.emacspeak ~/Projects/others/emacspeak/servers/mac-swiftmac/Makefile
	cp -f README.emacspeak.md ~/Projects/others/emacspeak/servers/mac-swiftmac/README.md
	cp -f cloud-swiftmac ~/Projects/others/emacspeak/servers/cloud-swiftmac
	cp -f log-swiftmac ~/Projects/others/emacspeak/servers/log-swiftmac

