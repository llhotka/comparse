.PHONY: test

all: lib/comparse.js

lib/comparse.js: src/comparse.litcoffee
	coffee --literate -o lib -c $<

test:
	@coffee test/test.coffee
