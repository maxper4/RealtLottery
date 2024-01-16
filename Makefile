-include .env

.PHONY: all coverage script

coverage:; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

script:;
	forge script ${script} --rpc-url ${GNOSIS_TESTNET_URL} --private-key ${PRIVATE_KEY} --broadcast --verify

verif:
	forge verify-contract ${address} ${name} --verifier-url https://gnosis-chiado.blockscout.com/api --watch