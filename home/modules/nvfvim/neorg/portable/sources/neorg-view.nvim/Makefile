NVIM ?= nvim
.PHONY: test test-integration bundle

test:
	$(NVIM) -u NONE -n -i NONE --headless -l tests/tables.lua
	$(NVIM) -u NONE -n -i NONE --headless -l tests/navigation.lua
	$(NVIM) -u NONE -n -i NONE --headless -l tests/reading.lua
	$(NVIM) -u NONE -n -i NONE --headless -l tests/journal.lua

test-integration:
	LUIX_YOUTUBE_NO_WATCH=1 $(NVIM) -n -i NONE --headless -c 'luafile tests/run.lua'
	LUIX_YOUTUBE_NO_WATCH=1 $(NVIM) -n -i NONE --headless -c 'luafile tests/journal-native.lua'

bundle:
	mkdir -p dist
	tar --exclude=doc/tags -czf dist/neorg-view.nvim.tar.gz README.md LICENSE Makefile lua doc integration tests
