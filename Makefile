.PHONY: help build test dev clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the plugin (creates dist/)
	@./scripts/package.sh

test: ## Run plugin validation tests
	@./scripts/test.sh

dev: build ## Build and start Claude Code with plugin loaded
	@echo ""
	@echo "Starting Claude Code with plugin loaded..."
	@echo ""
	@claude --plugin-dir ./dist/lookagain

eval: ## Run behavioral evals (requires ANTHROPIC_API_KEY)
	@npx promptfoo@latest eval -c evals/promptfooconfig.yaml

integration: build ## Run integration test (requires ANTHROPIC_API_KEY)
	@./scripts/integration-test.sh

clean: ## Remove build artifacts
	@rm -rf dist/
	@echo "Cleaned dist/"
