PREFIX=/usr/local

tacker: *.ha
	hare build -o tacker .

clean:
	rm -rf tacker

install: tacker
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f tacker $(DESTDIR)$(PREFIX)/bin/tacker
	chmod 755 $(DESTDIR)$(PREFIX)/bin/tacker

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/bin/tacker

.PHONY: clean install uninstall
