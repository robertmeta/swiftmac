EMACSPEAK := ~/.emacs.d/emacspeak
SERVERS := $(EMACSPEAK)/servers

install:
	cp swiftmac ~/.emacs.d/emacspeak/servers/swiftmac
	cp log-swiftmac ~/.emacs.d/emacspeak/servers/log-swiftmac
	chmod +x swiftmac
	chmod +x log-swiftmac
	chmod +x cloud-swiftmac
	sed -i '' '/swiftmac/d' $(SERVERS)/.servers
	echo "swiftmac" >>  $(SERVERS)/.servers
	echo "log-swiftmac" >>  $(SERVERS)/.servers
	echo "cloud-swiftmac" >> $(SERVERS)/.servers
	sort -o $(SERVERS)/.servers $(SERVERS)/.servers

format:
	swift-format swiftmac > new
	cat reinsert.header new > swiftmac
	rm new
	chmod +x swiftmac
