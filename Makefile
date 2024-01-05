EMACSPEAK := $(shell ./get-emacspeak-path.sh)
SERVERS := $(EMACSPEAK)/servers

debug:
	swift build

release:
	swift build -c release

fat-debug:
	swift build -c debug --triple arm64-apple-macosx
	swift build -c debug --triple x86_64-apple-macosx
	mkdir -p universal
	lipo -create .build/arm64-apple-macosx/debug/swiftmac .build/x86_64-apple-macosx/debug/swiftmac -output universal/swiftmac-debug
	lipo -info universal/swiftmac-debug

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

backup_if_exists:
	if [ -f $(SERVERS)/swiftmac ]; then \
	    cp $(SERVERS)/swiftmac $(SERVERS)/swiftmac.last_version; \
	fi

install-debug: debug support_files backup_if_exists
	cp .build/debug/swiftmac $(SERVERS)/swiftmac


install-binary: support_files backup_if_exists
	curl -L https://github.com/robertmeta/swiftmac/releases/download/alpha0.3/swiftmac --output $(SERVERS)/swiftmac
	chmod +x $(SERVERS)/swiftmac

install-binary-debug: support_files backup_if_exists
	curl -L https://github.com/robertmeta/swiftmac/releases/download/alpha0.3/swiftmac-debug --output  $(SERVERS)/swiftmac
	chmod +x $(SERVERS)/swiftmac

test: release
	python3 test-server.py .build/release/swiftmac

format:
	swift-format Package.swift > temp
	cp temp Package.swift
	swift-format Sources/SwiftMacPackage/swiftmac.swift > temp
	cp temp Sources/SwiftMacPackage/swiftmac.swift
	rm temp
