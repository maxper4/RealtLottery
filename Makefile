-include .env

.PHONY: all coverage script

coverage:; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

script:;
	forge script ${script} --rpc-url ${GNOSIS_TESTNET_URL} --private-key ${PRIVATE_KEY} --broadcast 

verif:
	forge verify-contract 0x8c33FfdeD8B413ea6180826f0de464117d829615 RealtLottery --verifier-url https://gnosis-chiado.blockscout.com/api --watch 