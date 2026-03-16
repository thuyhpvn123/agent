FORGE_STD = https://github.com/foundry-rs/forge-std
DS_TEST = https://github.com/dapphub/ds-test
FORGE_DIR = lib/forge-std
DS_TEST_DIR = lib/forge-std/lib/ds-test
all: unit-test

clone:
	@if [ ! -d "$(FORGE_DIR)" ]; then \
		echo "Cloning $(FORGE_STD) into $(FORGE_DIR)"; \
		git clone $(FORGE_STD) $(FORGE_DIR); \
	else \
		echo "Repository already exists in $(FORGE_DIR)"; \
	fi \

	@if [ ! -d "$(DS_TEST_DIR)/src" ]; then \
		echo "Cloning $(DS_TEST) into $(DS_TEST_DIR)"; \
		git clone $(DS_TEST) $(DS_TEST_DIR); \
	else \
		echo "Repository already exists in $(DS_TEST_DIR)"; \
	fi

	npm install

build:
	clear && forge build --via-ir

unit-test:
	clear && forge test -vvv

res:
	clear && forge test --match-path test/res_old.t.sol --via-ir -vvv
agent:
	clear && forge test --match-path test/agent_loyalty_v2.t.sol --via-ir -vvv
point:
	clear && forge test --match-path test/point.t.sol --via-ir -vvv

res1:
	clear && forge test --match-path test/res1.t.sol --via-ir -vvv