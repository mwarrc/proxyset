# ProxySet Makefile
# Standard installation paths
PREFIX ?= /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin
LIBDIR = $(DESTDIR)$(PREFIX)/lib/proxyset
MANDIR = $(DESTDIR)$(PREFIX)/share/man/man1
BASHCOMP = $(DESTDIR)/usr/share/bash-completion/completions

.PHONY: all install uninstall clean

all:
	@echo "Nothing to build. Run 'make install' to deploy ProxySet."

install:
	@echo "Installing ProxySet to $(PREFIX)..."
	# Create directories
	install -d $(BINDIR)
	install -d $(LIBDIR)/lib/core
	install -d $(LIBDIR)/lib/modules
	install -d $(MANDIR)
	install -d $(BASHCOMP)

	# Copy library files
	cp -r lib/core/*.sh $(LIBDIR)/lib/core/
	cp -r lib/modules/*.sh $(LIBDIR)/lib/modules/
	install -m 755 proxyset.sh $(LIBDIR)/proxyset.sh

	# Create wrapper script
	echo '#!/bin/bash' > $(BINDIR)/proxyset
	echo 'export PROXYSET_ROOT=$(PREFIX)/lib/proxyset' >> $(BINDIR)/proxyset
	echo 'exec bash "$$PROXYSET_ROOT/proxyset.sh" "$$@"' >> $(BINDIR)/proxyset
	chmod 755 $(BINDIR)/proxyset

	# Install documentation and completions
	install -m 644 proxyset.1 $(MANDIR)/proxyset.1
	if [ -f completions/proxyset.bash ]; then \
		install -m 644 completions/proxyset.bash $(BASHCOMP)/proxyset; \
	fi

	@echo "Update manual database..."
	-mandb > /dev/null 2>&1 || true

uninstall:
	@echo "Removing ProxySet..."
	rm -f $(BINDIR)/proxyset
	rm -rf $(LIBDIR)
	rm -f $(MANDIR)/proxyset.1
	rm -f $(BASHCOMP)/proxyset
	-mandb > /dev/null 2>&1 || true

clean:
	@echo "Cleaning up..."
