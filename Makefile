install:
	cp mac.swift ~/.emacs.d/emacspeak/servers/swiftmac
	cp log-swiftmac ~/.emacs.d/emacspeak/servers/log-swiftmac
	chmod +x ~/.emacs.d/emacspeak/servers/swiftmac
	chmod +x ~/.emacs.d/emacspeak/servers/log-swiftmac
	sed -i '' '/swiftmac/d' ~/.emacs.d/emacspeak/servers/.servers
	echo "swiftmac" >> ~/.emacs.d/emacspeak/servers/.servers
	echo "log-swiftmac" >> ~/.emacs.d/emacspeak/servers/.servers
