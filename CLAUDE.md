# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elixir-Slack is a Slack Real Time Messaging API client for Elixir. The library provides both RTM (Real Time Messaging) functionality for creating interactive bots and Web API functionality for making HTTP calls to Slack's API endpoints.

## Development Commands

### Core Commands
- `mix deps.get` - Install dependencies
- `mix deps.compile` - Compile dependencies
- `mix compile` - Compile the project
- `mix test` - Run the test suite
- `mix run --no-halt` - Run a bot application without halting

### Code Quality
- `mix format` - Format code according to `.formatter.exs` configuration
- `mix format --check-formatted` - Check if code is properly formatted (used in CI)
- `mix credo` - Run static code analysis with Credo linter
- `mix docs` - Generate documentation

### Testing
- `mix test` - Run all tests
- `mix test test/specific_test.exs` - Run a specific test file
- `mix test --cover` - Run tests with coverage reporting

## Architecture

### Core Modules

**`Slack`** (`lib/slack.ex`)
- Main entry point and behavior definition
- Provides macros for creating bot modules with callbacks:
  - `handle_connect/2` - called when connected to Slack
  - `handle_event/3` - called when a message/event is received  
  - `handle_close/3` - called when websocket connection closes
  - `handle_info/3` - called for other process messages

**`Slack.Bot`** (`lib/slack/bot.ex`)
- GenServer-like process that manages the WebSocket connection
- Implements `:websocket_client` behavior
- Entry point: `Slack.Bot.start_link/4`

**`Slack.Rtm`** (`lib/slack/rtm.ex`)
- Handles RTM API connection setup
- Makes HTTP calls to establish WebSocket connection
- Uses `rtm.start` endpoint (note: this is deprecated by Slack but still functional)

### Web API Architecture

**Generated Modules** (`lib/slack/web/`)
- Web API modules are dynamically generated from JSON documentation files
- Located in `lib/slack/web/docs/` directory
- `Slack.Web.Documentation` handles parsing and code generation
- Each Slack API endpoint becomes an Elixir function

**Key Web Modules:**
- `Slack.Web.Client` - HTTP client interface
- `Slack.Web.DefaultClient` - Default HTTPoison-based implementation
- Generated modules like `Slack.Web.Users`, `Slack.Web.Channels`, etc.

### Helper Modules

**`Slack.Lookups`** (`lib/slack/lookups.ex`)
- Utility functions for finding users, channels, groups by name/ID

**`Slack.Sends`** (`lib/slack/sends.ex`)
- Functions for sending messages: `send_message/3`, `send_raw/2`

**`Slack.State`** (`lib/slack/state.ex`)  
- State management for bot connections

## Configuration

### Web Client Configuration
```elixir
config :slack, api_token: "your-token-here"
config :slack, :web_http_client, YourApp.CustomClient
config :slack, :web_http_client_opts, [timeout: 10_000, recv_timeout: 10_000]
```

### Testing Configuration
```elixir
config :slack, url: "http://localhost:8000"  # For integration tests
```

## Key Dependencies

- **HTTPoison** (~> 1.2) - HTTP client for Web API calls
- **websocket_client** (~> 1.2.4) - WebSocket client for RTM connection  
- **Jason** (~> 1.1) - JSON encoding/decoding
- **Credo** (~> 0.5) - Static code analysis (dev/test only)

## Bot Development Pattern

1. Create a module that `use Slack`
2. Implement required callbacks (`handle_event/3` at minimum)  
3. Start with `Slack.Bot.start_link(YourModule, initial_state, token, options)`
4. Use `send_message/3` to send responses
5. Handle different event types in `handle_event/3` pattern matching

## API Migration Notes

The library uses the deprecated `rtm.start` endpoint. For new implementations, developers should consider:
- Making additional Web API calls to populate `bots`, `channels`, `groups`, `users`, and `ims` data
- Using `rtm.connect` approach as shown in the README upgrade guide

## Code Style

- Uses standard Elixir formatting (enforced via `mix format`)
- Credo configuration allows max line length of 80 characters
- Module documentation follows ExDoc conventions
- Test files follow pattern: `test/*_test.exs`