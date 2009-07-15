# This is a generated file, do not edit it. Use configure to modify it
PREFIX = /usr/local
MODE = --fixed

.PHONY: install

all:
	./configure --prefix=$(PREFIX) --nomake $(MODE)
test:
	./test.pl
install:
	mkdir -p $(PREFIX)/bin
	cp ./code2color ./sxw2txt ./lesspipe.sh $(PREFIX)/bin
	test -r $(PREFIX)/share/man/man1 && cp ./lesspipe.1 $(PREFIX)/share/man/man1
	chmod 0755 $(PREFIX)/bin/lesspipe.sh
	chmod 0755 $(PREFIX)/bin/sxw2txt
	chmod 0755 $(PREFIX)/bin/code2color
clean:
	mv Makefile Makefile.old
	rm -f lesspipe.sh
