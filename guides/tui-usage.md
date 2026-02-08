# TUI Usage Guide

The Hecate TUI provides a vim-style terminal interface for chatting with AI agents.

## Launching

```bash
hecate-tui
```

Or with a specific socket:

```bash
hecate-tui --socket /path/to/daemon.sock
```

## Interface Layout

```
┌────────────────────────────────────────────────────────────────┐
│ ● Daemon: healthy │ Model: llama3.2:latest │ Role: dna        │ <- Status Bar
├────────────────────────────────────────────────────────────────┤
│                                                                │
│ You:                                                           │
│ Hello, how are you?                                            │
│                                                                │
│ Hecate:                                                        │
│ I'm doing well, thank you for asking! How can I help you      │
│ today?                                                         │
│                                                                │ <- Chat Area
│                                                                │
│                                                                │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│ > Type your message here...                                    │ <- Input Field
├────────────────────────────────────────────────────────────────┤
│ i: insert │ Tab: model │ /: command │ ?: help                  │ <- Hints Bar
└────────────────────────────────────────────────────────────────┘
```

## Modes

The TUI uses vim-style modal editing.

### Normal Mode

Default mode for navigation and commands.

| Key | Action |
|-----|--------|
| `i` | Enter Insert mode |
| `/` | Enter Command mode |
| `Tab` | Cycle to next model |
| `Shift+Tab` | Cycle to previous model |
| `j` / `↓` | Scroll down |
| `k` / `↑` | Scroll up |
| `g` | Go to top |
| `G` | Go to bottom |
| `q` | Quit |
| `?` | Show help |

### Insert Mode

Mode for typing messages.

| Key | Action |
|-----|--------|
| `Esc` | Return to Normal mode |
| `Enter` | Send message |
| `↑` | Previous message from history |
| `↓` | Next message from history |
| `Ctrl+C` | Cancel current input |

### Command Mode

Mode for slash commands.

| Key | Action |
|-----|--------|
| `Esc` | Cancel and return to Normal mode |
| `Enter` | Execute command |
| `Tab` | Autocomplete command |

## Slash Commands

### Model Management

```
/models              List all available models
/model <name>        Switch to a specific model
```

### Personality & Roles

```
/roles               List available roles
/roles <code>        Switch to a role (dna, anp, tni, dno)
```

### Function Calling

```
/fn on               Enable tool/function calling
/fn off              Disable tool/function calling
/fn status           Show current function calling status
```

### Navigation

```
/browse              Open file browser (for context)
/clear               Clear chat history
```

### System

```
/help                Show help
/geo                 Check geographic restriction status
/quit                Exit the TUI
```

## Chat History

The TUI remembers your previous messages within a session.

- Press `↑` in Insert mode to recall the previous message
- Press `↓` to go forward in history
- History is cleared when you exit

## Model Selection

### Quick Switching

Press `Tab` in Normal mode to cycle through available models. The current model is shown in the status bar.

### List All Models

Use `/models` to see all available models with their providers:

```
Available Models:
  [ollama] llama3.2:latest
  [ollama] codellama:latest
  [anthropic] claude-3-5-sonnet-20241022
  [openai] gpt-4-turbo
```

### Switch to Specific Model

```
/model claude-3-5-sonnet-20241022
```

## Status Indicators

### Daemon Status

| Indicator | Meaning |
|-----------|---------|
| `●` (green) | Daemon healthy and connected |
| `◐` (yellow) | Connecting or loading |
| `●` (red) | Daemon unreachable or error |

### Model Status

| Indicator | Meaning |
|-----------|---------|
| `●` (green) | Model ready |
| `◐` (yellow) | Model loading |
| `●` (red) | Model error (check hints for details) |

## Streaming Responses

When you send a message, the response streams in real-time. You'll see the text appear word by word as the model generates it.

To cancel a streaming response, press `Ctrl+C`.

## Configuration

Configuration is stored in `~/.config/hecate-tui/config.toml`.

```toml
[daemon]
socket_path = "/run/hecate/daemon.sock"

[personality]
personality_file = "~/hecate-agents/PERSONALITY.md"
roles_dir = "~/hecate-agents/philosophy"
active_role = "dna"

[ui]
theme = "dark"  # or "light"
```

### Socket Path

Default: `/run/hecate/daemon.sock`

For custom installations, update this path.

### Personality File

Point to a markdown file containing personality traits. See [Personality System](personality-system.md).

### Roles Directory

Directory containing role definition files. Each role is a markdown file like `DNA.md`, `ANP.md`, etc.

## Keyboard Reference

### Normal Mode

| Key | Action |
|-----|--------|
| `i` | Insert mode |
| `/` | Command mode |
| `Tab` | Next model |
| `Shift+Tab` | Previous model |
| `j` / `↓` | Scroll down |
| `k` / `↑` | Scroll up |
| `g` | Top |
| `G` | Bottom |
| `q` | Quit |
| `?` | Help |

### Insert Mode

| Key | Action |
|-----|--------|
| `Esc` | Normal mode |
| `Enter` | Send |
| `↑` | History back |
| `↓` | History forward |
| `Ctrl+C` | Cancel |

### Command Mode

| Key | Action |
|-----|--------|
| `Esc` | Cancel |
| `Enter` | Execute |
| `Tab` | Autocomplete |
