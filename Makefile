.PHONY: lint test check

# lint and test are always verbose. check is terse: suppress everything on
# success, dump the full log on any failure -- matching the intent (not
# necessarily the literal dots) of Go's/Ruby's/Kotlin's own lint/test/check
# split in this account (see humane/humane-ruby/humane-swift's Makefiles).

lint:
	swiftlint

# Verbose on purpose -- ./test.sh pipes xcodebuild test's raw output through
# xctidy for RSpec -fd-style nested describe/context/it output, the same
# tool humane-swift's own `test` target uses.
test:
	./test.sh

# Terser than `test` on purpose: xcodebuild/xctidy have no quiet mode of
# their own, so this just suppresses output on success and dumps the full
# log on failure, guaranteeing errors are never hidden regardless of
# xcodebuild's exact output format.
check: lint
	@LOG=$$(mktemp); \
	if ./test.sh > "$$LOG" 2>&1; then \
		echo "PASS"; \
	else \
		cat "$$LOG"; \
		rm -f "$$LOG"; \
		exit 1; \
	fi; \
	rm -f "$$LOG"
