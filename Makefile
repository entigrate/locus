.PHONY: build run release format lint check test clean setup

# Build the app bundle
build:
	./Scripts/build.sh

# Build with permission reset
build-reset:
	./Scripts/build.sh --reset

# Run the app
run: build
	open "Locus Dev.app"

# Signed, notarized release DMG
release:
	./Scripts/build.sh --release

# Auto-format all Swift files
format:
	swiftformat Sources/ Tests/ --config .swiftformat

# Lint (SwiftFormat check + SwiftLint strict)
lint:
	swiftformat --lint Sources/ Tests/ --config .swiftformat
	mint run swiftlint lint --strict

# Run all quality checks (format + lint + build + test)
check: format
	mint run swiftlint lint --strict
	swift build -c debug
	swift test
	@echo "All checks passed."

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
	rm -rf Locus.app "Locus Dev.app"

# First-time setup: install tools and configure git hooks
setup:
	@echo "Installing development tools..."
	brew install swiftformat || true
	brew install mint || true
	mint install realm/SwiftLint || true
	@echo "Configuring git hooks..."
	git config core.hooksPath .githooks
	@echo "Setup complete. Run 'make check' to verify."
