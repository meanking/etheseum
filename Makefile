.PHONY: test

compile:
	rm -rf build
	SOLC_VERSION=native truffle compile --network test

test:
	SOLC_VERSION=native truffle test --network test

test-ganache:
	SOLC_VERSION=native truffle test --network ganache

migrate:
	SOLC_VERSION=native truffle migrate --network ganache

complete:
	NODE_URL=http://0.0.0.0:8545 npm run complete

