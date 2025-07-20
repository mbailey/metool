.PHONY: test test-clone test-install test-edit test-sync test-completion tmux dev
.PHONY: mcp-install mcp-dev-install mcp-test mcp-build mcp-publish-test mcp-publish mcp-release mcp-clean

test: test-clone test-install test-edit test-sync test-completion

test-clone:
	bats tests/clone.bats

test-install:
	bats tests/install.bats

test-edit:
	MT_LOG_LEVEL=ERROR BATS_TEST_TIMEOUT=30 bats tests/edit.bats

test-edit-remaining:
	MT_LOG_LEVEL=ERROR BATS_TEST_TIMEOUT=30 bats tests/edit.bats --filter "mt edit can create a new package with confirmation|mt edit can cancel creating a new package|mt edit fails for non-existent module|mt edit_function displays error if function not found|mt edit_executable displays error if executable not found|mt edit_function can edit a function with line number"
	
test-edit-known-good:
	MT_LOG_LEVEL=ERROR BATS_TEST_TIMEOUT=30 bats tests/edit.bats --filter "mt edit shows usage when no arguments provided|mt edit can edit a package README|mt edit can edit a package by name|mt edit creates README.md if it doesn't exist|mt edit can edit a module/package path|mt edit can edit a function|mt edit can edit an executable|mt edit can edit a file|mt edit errors on non-existent target"

test-sync:
	bats tests/sync.bats

test-completion:
	bats tests/completion.bats

# Development targets
dev:
	@echo "Starting development mode..."
	@echo "Use 'make tmux' for a beautiful tmux layout"
	MT_LOG_LEVEL=DEBUG bats --tap tests/ --watch

tmux:
	@echo "Starting metool development environment in tmux..."
	@bash -c ' \
		PROJECT_ROOT="$$(pwd)"; \
		SESSION_NAME="metool-dev"; \
		WINDOW_NAME="dev"; \
		\
		if [ -n "$$TMUX" ]; then \
			echo "Already in tmux session. Creating new window..."; \
			tmux new-window -n "$$WINDOW_NAME" -c "$$PROJECT_ROOT"; \
			TMUX_TARGET="$$WINDOW_NAME"; \
		else \
			echo "Creating new tmux session..."; \
			tmux new-session -d -s "$$SESSION_NAME" -n "$$WINDOW_NAME" -c "$$PROJECT_ROOT"; \
			TMUX_TARGET="$$SESSION_NAME:$$WINDOW_NAME"; \
		fi; \
		\
		echo "Setting up panes..."; \
		tmux send-keys -t "$$TMUX_TARGET" "echo \"=== File Watcher ===\" && echo \"Watching lib/ and shell/ for changes...\"" Enter; \
		tmux send-keys -t "$$TMUX_TARGET" "find lib shell -name \"*.sh\" -o -name \"mt\" -o -name \"aliases\" -o -name \"functions\" | entr -c ls -la" Enter; \
		\
		tmux split-window -t "$$TMUX_TARGET" -v -p 70 -c "$$PROJECT_ROOT"; \
		tmux send-keys -t "$$TMUX_TARGET.1" "echo \"=== Test Runner ===\" && echo \"Running tests in watch mode...\"" Enter; \
		tmux send-keys -t "$$TMUX_TARGET.1" "MT_LOG_LEVEL=DEBUG find tests lib shell -name \"*.bats\" -o -name \"*.sh\" -o -name \"mt\" | entr -c make test" Enter; \
		\
		tmux split-window -t "$$TMUX_TARGET.1" -h -p 50 -c "$$PROJECT_ROOT"; \
		tmux send-keys -t "$$TMUX_TARGET.2" "echo \"=== Debug Logs ===\" && echo \"Monitoring metool debug output...\"" Enter; \
		tmux send-keys -t "$$TMUX_TARGET.2" "echo \"Run metool commands with MT_LOG_LEVEL=DEBUG to see logs here\"" Enter; \
		tmux send-keys -t "$$TMUX_TARGET.2" "tail -f /dev/null" Enter; \
		\
		tmux split-window -t "$$TMUX_TARGET.1" -v -p 30 -c "$$PROJECT_ROOT"; \
		tmux send-keys -t "$$TMUX_TARGET.3" "echo \"=== Interactive Shell ===\" && echo \"Ready for metool commands...\"" Enter; \
		tmux send-keys -t "$$TMUX_TARGET.3" "export MT_LOG_LEVEL=DEBUG" Enter; \
		tmux send-keys -t "$$TMUX_TARGET.3" "source shell/mt" Enter; \
		\
		tmux select-pane -t "$$TMUX_TARGET.3"; \
		\
		if [ -z "$$TMUX" ]; then \
			echo "Attaching to session..."; \
			tmux attach-session -t "$$SESSION_NAME"; \
		else \
			echo "Switched to new window in current session"; \
		fi \
	'

# MCP Server targets
mcp-install:
	@echo "Installing metool-mcp..."
	@cd mcp && pip install -e .
	@echo "MCP server installation complete!"

mcp-dev-install:
	@echo "Installing metool-mcp with development dependencies..."
	@cd mcp && pip install -e .
	@cd mcp && pip install pytest pytest-asyncio
	@echo "MCP server development installation complete!"

mcp-test:
	@echo "Running MCP server tests..."
	@cd mcp && python -m pytest tests/ -v --tb=short
	@echo "MCP tests completed!"

mcp-build:
	@echo "Building MCP Python package..."
	@cd mcp && python -m build
	@echo "MCP package built successfully in mcp/dist/"

mcp-test-package: mcp-build
	@echo "Testing MCP package installation..."
	@cd mcp && rm -rf test-env
	@cd mcp && python -m venv test-env
	@cd mcp && ./test-env/bin/pip install --upgrade pip
	@cd mcp && ./test-env/bin/pip install dist/*.whl
	@echo "Testing installed package..."
	@cd mcp && ./test-env/bin/python -c "from metool_mcp.server import mcp; print('Import successful!')"
	@cd mcp && rm -rf test-env
	@echo "MCP package test successful!"

mcp-publish-test: mcp-build
	@echo "Publishing to TestPyPI..."
	@echo "Make sure you have configured ~/.pypirc with testpypi credentials"
	@cd mcp && twine upload --repository testpypi dist/*

mcp-publish: mcp-build
	@echo "Publishing to PyPI..."
	@echo "Make sure you have configured ~/.pypirc with pypi credentials"
	@cd mcp && twine upload dist/*

mcp-release:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Usage: make mcp-release VERSION=0.1.0"; \
		exit 1; \
	fi
	@echo "Creating MCP release $(VERSION)..."
	@echo "Updating version in pyproject.toml..."
	@sed -i 's/^version = ".*"/version = "$(VERSION)"/' mcp/pyproject.toml
	@git add mcp/pyproject.toml
	@git commit -m "chore: bump metool-mcp version to $(VERSION)"
	@git tag -a "mcp-v$(VERSION)" -m "Release metool-mcp v$(VERSION)"
	@echo "Pushing changes and tags..."
	@git push origin HEAD
	@git push origin "mcp-v$(VERSION)"
	@echo "MCP release $(VERSION) created!"

mcp-clean:
	@echo "Cleaning MCP build artifacts..."
	@cd mcp && rm -rf dist/ build/ *.egg-info
	@cd mcp && rm -rf .pytest_cache __pycache__ tests/__pycache__
	@find mcp -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find mcp -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "MCP clean complete!"