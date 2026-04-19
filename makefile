# Resolve TELEGRAM_STATE_DIR automatically:
#   1. If ~/.claude/channels/telegram-<repo-dir-name>/ exists (created by setup.sh
#      when you picked a nickname), use it. This keeps multi-bot setups isolated.
#   2. Otherwise fall back to the plugin's bare default ~/.claude/channels/telegram/.
# Override either at invocation time, e.g.:
#   make run NICK=other          → ~/.claude/channels/telegram-other/
#   make run TELEGRAM_STATE_DIR=/custom/path
NICK ?= $(notdir $(CURDIR))
TELEGRAM_STATE_DIR ?= $(if $(wildcard $(HOME)/.claude/channels/telegram-$(NICK)),$(HOME)/.claude/channels/telegram-$(NICK),$(HOME)/.claude/channels/telegram)

.PHONY: run
run:
	TELEGRAM_STATE_DIR=$(TELEGRAM_STATE_DIR) \
		claude --channels plugin:telegram@claude-plugins-official
