.PHONY: all coverage

coverage:; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage