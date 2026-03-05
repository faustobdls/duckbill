# 🦆 Duckbill

Duckbill is a **Privacy-first** AI CLI and Server natively written in Dart for high performance. It enables remote AI-powered agent execution over a secure N-N WebSocket architecture, with **local** suggestion execution (like Claude Code), an interactive terminal menu, and reusable packages following **SOLID** and **Clean Architecture** principles.

_Read in other languages: [Português](README.md), [Español](README-es.md)._

---

## ✨ Features

- **Privacy First:** You decide where and how AI runs — minimal data collection.
- **N-N Architecture:** Connect multiple clients to multiple servers over WebSocket.
- **Local Suggestion Execution:** The client receives AI suggestions and executes them **on your machine** with per-suggestion approval — just like Claude Code or OpenClaw.
- **Remote Model Configuration:** The server pushes model/provider info via a `config` frame after the WebSocket handshake. The client doesn't need to know the AI configuration in advance.
- **Interactive Console Menu:** Run `duckbill` with no arguments to enter interactive mode with a numbered menu and AI chat interface.
- **Typed Message Protocol:** Structured JSON frames (`prompt`, `response`, `suggestion`, `execution_result`, `config`, `stream_end`, `error`) for precise routing.
- **Secure WebSocket Tunnel:** Bearer Token handshake + HMAC-SHA256 with 180s TTL on every payload.
- **Local Credential Storage:** PATs encrypted with AES-256-GCM in `~/.duckbill/keys/`.
- **SQLite Database:** WAL mode, native FFI bindings, high concurrency.
- **Test Coverage ≥ 90%:** Comprehensive test suites across all packages.

---

## 🏗️ Architecture (SOLID + Clean Architecture)

```
┌─────────────────────────────────────────────────────┐
│               Presentation Layer                    │
│         CLI (duckbill) · Interactive Menu           │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│           Application / Use-Case Layer              │
│       AgentSession · InteractiveRunner              │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
┌──────────▼──────────┐  ┌────────▼───────────────────┐
│    Domain Layer     │  │   Infrastructure Layer      │
│  AiSuggestion       │  │  duckbill_crypto  (AES-GCM) │
│  ExecutionGate      │  │  duckbill_storage (SQLite)  │
│  LocalExecutor      │  │  duckbill_protocol (WS+HMAC)│
│  MessageFrame       │  │  duckbill_ai      (Gemini)  │
└─────────────────────┘  └────────────────────────────┘
```

### Packages

| Package | Responsibility |
|---|---|
| `duckbill_crypto` | AES-256-GCM encryption, PAT storage |
| `duckbill_storage` | SQLite (WAL), JSON config |
| `duckbill_protocol` | WebSocket, HMAC-SHA256, `MessageFrame`, `MessageRouter`, `ClientRegistry` |
| `duckbill_ai` | Gemini adapter, `FunctionParser` |
| `duckbill_agent` | `AgentSession`, `LocalExecutor`, `ExecutionGate`, `SuggestionParser` |
| `duckbill_console` | Interactive menu, chat TUI, ANSI styles |

---

## 💻 Usage

### Interactive Mode (New!)

Run without arguments to get the menu:

```bash
duckbill
```

Menu options:
- **Interactive AI Session** — multi-turn chat with per-suggestion approval
- **Run Single Prompt** — send one prompt and exit
- **Save Auth Token** — store your PAT encrypted
- **Start Server** — launch the WebSocket server
- **Version Info** / **Update**

### Command Line

#### 1. Save your authentication token

```bash
duckbill auth login --token YOUR_SECRET_TOKEN
```

#### 2. Start the server

```bash
export GEMINI_API_KEY="YOUR_GEMINI_KEY"
duckbill server start --port 8080
```

#### 3. Interactive session (Claude Code style)

```bash
# Manual approval for each suggestion:
duckbill agent interactive

# Auto-approve (CI/automated pipelines):
duckbill agent interactive --auto-approve
```

#### 4. Single prompt

```bash
duckbill agent run "Check disk space."
duckbill agent run --auto-approve "List running processes."
```

---

## 🔐 Security

| Layer | Mechanism |
|---|---|
| WebSocket Handshake | Bearer Token in `Authorization` header |
| Payload | HMAC-SHA256 signature + 180s TTL |
| Local storage | AES-256-GCM in `~/.duckbill/keys/auth.json` |
| Execution approval | Interactive gate (user approves each suggestion) |

---

## 📦 Message Protocol

All communication uses structured JSON frames:

```json
// Client → Server
{"type": "prompt",           "payload": {"text": "..."}, "ts": 1234567890}

// Server → Client (after handshake)
{"type": "config",           "payload": {"model": "gemini-3", "provider": "gemini"}, "ts": ...}

// Server → Client (AI response)
{"type": "suggestion",       "payload": {"command": "ls -la", "explanation": "..."}, "ts": ...}
{"type": "response",         "payload": {"text": "..."}, "ts": ...}
{"type": "stream_end",       "payload": {}, "ts": ...}

// Client → Server (local execution result)
{"type": "execution_result", "payload": {"exit_code": 0, "stdout": "...", "stderr": ""}, "ts": ...}
```

---

## 🚀 Build and Deploy

The CI/CD pipeline (GitHub Actions) builds for multiple platforms when you push a `v*` tag:

```bash
git tag v1.0.0 && git push --tags
```

Platforms: Linux x86_64/ARM64, macOS Intel/Apple Silicon, Windows x86_64.

Manual install:

```bash
curl -LO https://github.com/YOUR_REPO/duckbill/releases/latest/download/duckbill-cli-linux-amd64.tar.gz
mkdir -p ~/.local/opt/duckbill && tar -xzf duckbill-cli-linux-amd64.tar.gz -C ~/.local/opt/duckbill
ln -s ~/.local/opt/duckbill/bin/cli ~/.local/bin/duckbill
```

---

## 🧪 Testing

```bash
for dir in packages/duckbill_crypto packages/duckbill_storage packages/duckbill_protocol \
           packages/duckbill_ai packages/duckbill_agent packages/duckbill_console server cli; do
  (cd $dir && dart test)
done
```

Target coverage: **≥ 90%** per package.

---

## 🛠️ Architectural Changes from Original Plan

1. **Local Execution:** Instead of the server executing commands on the server, the **client** receives suggestions and executes them locally, with per-suggestion approval. The server acts as a router/orchestrator, not an executor.
2. **Typed Protocol:** All WebSocket frames now carry a `type` + `payload` JSON envelope, eliminating fragile string parsing.
3. **New Packages:** `duckbill_agent` (local execution + approval gate) and `duckbill_console` (TUI menu + ANSI styles).
4. **SOLID Server:** `DuckbillServer` delegates to `ClientHandler`, `AiRequestHandler`, `ConfigSyncHandler`, `ClientRegistry`, and `MessageRouter`.
5. **Interactive Menu:** The CLI detects missing arguments and presents a TUI-style interactive menu.
