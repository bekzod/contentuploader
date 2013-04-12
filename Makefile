
generate-js: remove-js
	@coffee -c --bare -o lib src

remove-js:
	@rm -fr lib/

.PHONY: generate-js