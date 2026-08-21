.PHONY: all build release app universal run install uninstall clean help

INSTALL_DIR ?= /Applications

# Default target
all: build

## build: Compiles the debug executable with Swift PM
build:
	@echo "🔨 Building jbar (debug)..."
	swift build

## app / release: Compiles release binary and packages into build/jbar.app
release app:
	@echo "📦 Creating jbar.app release bundle..."
	./build_app.sh

## universal: Compiles universal binary (arm64 + x86_64) and packages jbar.app
universal:
	@echo "🌐 Building universal release bundle..."
	./build_app.sh --universal

## run: Builds (if needed) and opens jbar.app
run: app
	@echo "👉 Launching jbar.app..."
	open build/jbar.app

## install: Builds and copies jbar.app to /Applications
install: app
	@echo "📦 Installing jbar.app to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/jbar.app"
	@cp -R "build/jbar.app" "$(INSTALL_DIR)/"
	@echo "✅ Successfully installed to $(INSTALL_DIR)/jbar.app"

## uninstall: Removes jbar.app from /Applications
uninstall:
	@echo "🗑️ Removing jbar.app from $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/jbar.app"
	@echo "✅ Removed $(INSTALL_DIR)/jbar.app"

## clean: Removes build artifacts and Swift PM caches
clean:
	@echo "🧹 Cleaning build artifacts..."
	swift package clean 2>/dev/null || true
	rm -rf .build build

## help: Display this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       Compile debug executable (default)"
	@echo "  app         Build signed release application bundle (build/jbar.app)"
	@echo "  universal   Build universal release bundle (Apple Silicon + Intel)"
	@echo "  run         Build and launch jbar.app"
	@echo "  install     Build and copy jbar.app to /Applications"
	@echo "  uninstall   Remove jbar.app from /Applications"
	@echo "  clean       Remove all build directories and intermediate files"
	@echo "  help        Show this help message"
