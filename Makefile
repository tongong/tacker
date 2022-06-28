PREFIX=/usr/local

SRC = *.ha searchio/*.ha
tacker: $(SRC)
	hare build -o tacker

test:
	hare test

clean:
	rm -rf tacker

install: tacker
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f tacker $(DESTDIR)$(PREFIX)/bin/tacker
	chmod 755 $(DESTDIR)$(PREFIX)/bin/tacker

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/bin/tacker

.PHONY: test clean install uninstall
