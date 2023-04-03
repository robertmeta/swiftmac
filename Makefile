EMACSPEAK := ~/.emacs.d/emacspeak
SERVERS := $(EMACSPEAK)/servers

debug:
	swift build

release:
	swift build -c release

support_files:
	cp cloud-swiftmac $(SERVERS)/cloud-swiftmac
	cp log-swiftmac $(SERVERS)/log-swiftmac
	sed -i '' '/swiftmac/d' $(SERVERS)/.servers
	echo "swiftmac" >>  $(SERVERS)/.servers
	echo "log-swiftmac" >>  $(SERVERS)/.servers
	echo "cloud-swiftmac" >> $(SERVERS)/.servers
	sort -o $(SERVERS)/.servers $(SERVERS)/.servers

install: release support_files 
	cp .build/release/swiftmac $(SERVERS)/swiftmac

install-debug: debug support_files 
	cp .build/debug/swiftmac $(SERVERS)/swiftmac

test: release
	python3 test-server.py .build/release/swiftmac

format:
	swift-format Package.swift > temp
	cp temp Package.swift
	swift-format Sources/SwiftMacPackage/swiftmac.swift > temp
	cp temp Sources/SwiftMacPackage/swiftmac.swift
	rm temp
