EMACSPEAK := $(shell ./get-emacspeak-path.sh)
SERVERS := $(EMACSPEAK)/servers
LISP := $(EMACSPEAK)/lisp

quick:
	swift build

release: clean
	swift build -c release 

debug: clean
	swift build 

support-files:
	cp cloud-swiftmac $(SERVERS)/cloud-swiftmac
	cp swiftmac-voices.el $(LISP)/swiftmac-voice.el
	cp log-swiftmac $(SERVERS)/log-swiftmac
	sed -i '' '/swiftmac/d' $(SERVERS)/.servers
	echo "swiftmac" >>  $(SERVERS)/.servers
	echo "log-swiftmac" >> $(SERVERS)/.servers
	echo "cloud-swiftmac" >> $(SERVERS)/.servers
	sort -o $(SERVERS)/.servers $(SERVERS)/.servers

install: release support-files backup-if-exists
	cp .build/release/swiftmac $(SERVERS)/swiftmac
	cp -rf .build/release/ogg.framework $(SERVERS)/ogg.framework
	cp -rf .build/release/vorbis.framework $(SERVERS)/vorbis.framework

install-debug: debug support-files backup-if-exists
	cp .build/debug/swiftmac $(SERVERS)/swiftmac

backup-if-exists:
	if [ -f $(SERVERS)/swiftmac ]; then cp $(SERVERS)/swiftmac	\
	$(SERVERS)/swiftmac.last_version; fi

restore-from-backup:
	if [ -f $(SERVERS)/swiftmac.last_version ]; then \
	    cp $(SERVERS)/swiftmac.last_version $(SERVERS)/swiftmac
	fi


tidy:
	swift-format Package.swift > temp
	cp temp Package.swift
	swift-format Sources/SwiftMacPackage/logger.swift > temp
	cp temp Sources/SwiftMacPackage/logger.swift 
	swift-format Sources/SwiftMacPackage/statestore.swift > temp
	cp temp Sources/SwiftMacPackage/statestore.swift 
	swift-format Sources/SwiftMacPackage/main.swift > temp
	cp temp Sources/SwiftMacPackage/main.swift 
	swift-format Sources/SwiftMacPackage/toneplayer.swift > temp
	cp temp Sources/SwiftMacPackage/toneplayer.swift 
	rm temp

contribute: tidy
	mkdir -p ~/Projects/others/emacspeak/servers/mac-swiftmac/
	rm -rf ~/Projects/others/emacspeak/servers/mac-swiftmac/*
	cp -Rvf * ~/Projects/others/emacspeak/servers/mac-swiftmac
	cp -Rvf .gitignore ~/Projects/others/emacspeak/servers/mac-swiftmac
	cp -f .gitignore ~/Projects/others/emacspeak/servers/mac-swiftmac
	rm -f ~/Projects/others/emacspeak/servers/README.emacspeak.org
	rm -f ~/Projects/others/emacspeak/servers/Makefile.emacspeak.org
	cp -f Makefile.emacspeak ~/Projects/others/emacspeak/servers/mac-swiftmac/Makefile
	cp -f README.emacspeak.org ~/Projects/others/emacspeak/servers/mac-swiftmac/README.org
	cp -f cloud-swiftmac ~/Projects/others/emacspeak/servers/cloud-swiftmac
	cp -f log-swiftmac ~/Projects/others/emacspeak/servers/log-swiftmac

clean:
	swift package clean
