install:
	cp swiftmac ~/.emacs.d/emacspeak/servers/swiftmac
	cp log-swiftmac ~/.emacs.d/emacspeak/servers/log-swiftmac
	chmod +x swiftmac
	chmod +x log-swiftmac
	chmod +x debug-swiftmac
	chmod +x cloud-swiftmac
	sed -i '' '/swiftmac/d' ~/.emacs.d/emacspeak/servers/.servers
	echo "swiftmac" >> ~/.emacs.d/emacspeak/servers/.servers
	echo "log-swiftmac" >> ~/.emacs.d/emacspeak/servers/.servers
	echo "debug-swiftmac" >> ~/.emacs.d/emacspeak/servers/.servers
	echo "cloud-swiftmac" >> ~/.emacs.d/emacspeak/servers/.servers


format:
	swift-format --maxwidth=79 swiftmac > new
	cat reinsert.header new > swiftmac
	rm new
	chmod +x swiftmac
