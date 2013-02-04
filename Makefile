# This is a generated file, do not edit it. Use configure to modify it
PREFIX = /usr/local
MODE = --fixed

.PHONY: install

all:
	./configure --prefix=$(PREFIX) --nomake $(MODE)
test:
	./test.pl
install:
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	cp ./code2color ./sxw2txt ./tarcolor ./lesspipe.sh $(DESTDIR)$(PREFIX)/bin
	cp ./lesspipe.1 $(DESTDIR)$(PREFIX)/share/man/man1
	chmod 0755 $(DESTDIR)$(PREFIX)/bin/lesspipe.sh
	chmod 0755 $(DESTDIR)$(PREFIX)/bin/sxw2txt
	chmod 0755 $(DESTDIR)$(PREFIX)/bin/code2color
	chmod 0755 $(DESTDIR)$(PREFIX)/bin/tarcolor
clean:
	mv Makefile Makefile.old
	rm -f lesspipe.sh
