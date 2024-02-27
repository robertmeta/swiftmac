EMACSPEAK := $(shell ./get-emacspeak-path.sh)
SERVERS := $(EMACSPEAK)/servers

release: clean
	swift build -c release -Xlinker -rpath -Xlinker @executable_path/../Frameworks

debug: clean
	swift build -Xlinker -rpath -Xlinker @executable_path/../Frameworks

fat-release:
	swift build -c release --triple arm64-apple-macosx
	swift build -c release --triple x86_64-apple-macosx
	mkdir -p universal
	lipo -create .build/arm64-apple-macosx/release/swiftmac .build/x86_64-apple-macosx/release/swiftmac -output universal/swiftmac
	lipo -info universal/swiftmac

support-files:
	cp cloud-swiftmac $(SERVERS)/cloud-swiftmac
	cp log-swiftmac $(SERVERS)/log-swiftmac
	sed -i '' '/swiftmac/d' $(SERVERS)/.servers
	echo "swiftmac" >>  $(SERVERS)/.servers
	echo "log-swiftmac" >>  $(SERVERS)/.servers
	echo "cloud-swiftmac" >> $(SERVERS)/.servers
	sort -o $(SERVERS)/.servers $(SERVERS)/.servers

install: release support-files backup-if-exists
	cp .build/release/swiftmac $(SERVERS)/swiftmac
	cp -rf .build/release/ogg.framework $(SERVERS)/ogg.framework
	cp -rf .build/release/vorbis.framework $(SERVERS)/vorbis.framework

install-debug: debug support-files backup-if-exists
	cp .build/debug/swiftmac $(SERVERS)/swiftmac

backup-if-exists:
	if [ -f $(SERVERS)/swiftmac ]; then \
	    cp $(SERVERS)/swiftmac $(SERVERS)/swiftmac.last_version; \
	fi

restore-from-backup:
	if [ -f $(SERVERS)/swiftmac.last_version ]; then \
	    cp $(SERVERS)/swiftmac.last_version $(SERVERS)/swiftmac
	fi


install-binary: support-files backup-if-exists
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

clean:
	swift package clean
	rm -rf swiftmac.app

build-app: release
	mkdir -p swiftmac.app
	mkdir -p swiftmac.app/Contents
	mkdir -p swiftmac.app/Contents/MacOS
	mkdir -p swiftmac.app/Contents/Frameworks
	cp Info.plist swiftmac.app/Contents
	cp ./.build/release/swiftmac swiftmac.app/Contents/MacOS
	cp -Rf ./.build/release/ogg.framework swiftmac.app/Contents/Frameworks
	cp -Rf ./.build/release/vorbis.framework swiftmac.app/Contents/Frameworks
	chmod +x swiftmac.app
	chmod +x swiftmac.app/Contents/Frameworks
