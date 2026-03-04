# 🦆 Duckbill

Duckbill is a **Privacy-first** AI Server and CLI natively written in Dart to ensure high-performance capabilities. It allows you to run AI-powered autonomous agents remotely, creating secure tunnels to perform automated system executions natively on your machine via Model Context Protocols (MCPs) coupled with fine-grained granular secure permissions.

_Read in other languages: [Português](README.md), [Español](README-es.md)._

## ✨ Features

- **Privacy First:** Less data footprint, you hold complete control and exclusively isolate the AI executions.
- **N-N Architecture:** Seamlessly interconnect multiple clients (CLIs) to various concurrent servers.
- **Autonomous AI & Deep Reasoning:** Defaults natively to the `gemini-3-flash-preview` paired with a HIGH "Thinking Level" to execute thoughtful internal shell decisions tailored to your host machine's architecture environment.
- **Secure WebSocket Tunneling:** Built-in end-to-end payload transit encryption spanning from TLS Pinning configurations seamlessly validated through standard HMAC-SHA256 handshake tokens per message via precise TTLS timeout protocols.
- **Local Credential Storage:** Secured Personal Access Tokens (PATs) locally housed in AES-256-GCM sealed envelopes mechanism.
- **Optimized Storage Backing:** High-concurrency sqlite connection utilizing system C++ FFI layers optimized to write ahead logs (WAL) to robustly sustain constant polling from multiple simultaneous endpoints.

---

## 🛠️ Original Architectural Plan Deviations

In order to better align the project codebase to standard native conventions and provide immediate stable FFI abstraction mappings, slight modifications were made to the original ideal layout structure:

1. **Folder Scaffold Remodeling:** Instead of tucking apps into an aggregate generic `apps/` base folder and nesting huge bulk monolith packages down in one giant chunk core, they were atomized. Independent packages trace independently to (`packages/duckbill_ai`, `packages/duckbill_crypto`, `packages/duckbill_protocol`, and `packages/duckbill_storage`), keeping `cli/` and `server/` isolated strictly on their own root directories preventing cross-injection pollution bindings.
2. **Compilation Infrastructure Overhaul:** The initial prompt specified using `dart compile exe`. By adopting `sqlite3` alongside cutting edge generic Dynamic C++ FFI bindings integrations, the strategy shifted modernly into `dart build cli`. Such approach guarantees the extraction of dependent `.dylib`/`.so` linked libraries paired in exact tandem with the main binary output.
3. **Internal Autonomy Empowerments:** The AI model doesn't just reply gracefully via generic raw markdown answers anymore. Advanced functional structures parse incoming queries specifically formatting payload requests mapped out in strict actionable command blocks bridging natively back to the host bash server tunneling mechanism under WebSocket.

---

## 💻 Local Development Setup (How to run locally)

Throughout standard development phases, running pure Dart components combined with simple base JIT compilation hot restarts allows minimal overhead execution natively in the shell.

1. **Start the local server:**
   Navigate internally, provide your AI remote access key natively through enviroment shells, and spin the server upon the default port 8080:

```bash
cd server
export GEMINI_API_KEY="YOUR_KEY_HERE"
dart run bin/server.dart
```

2. **Generate your authentication base PAT Token in parallel mode:**

```bash
cd cli
dart run bin/cli.dart auth login --token YOUR_SECRET_ACCESS_TOKEN
```

3. **Establish CLI payload handshakes mapping Server Tunneled AI execution:**

```bash
cd cli
dart run bin/cli.dart agent run "Check available disk storage on this computer."
```

---

## 🚀 Building & Deploying (Production Workloads)

Refrain from manually dealing with compiling cross-machine OS architectures natively. Let CI/CD continuous delivery take control exclusively through **GitHub Actions**.

Whenever committing pushes onto your `main` primary branch, remote headless Ubuntu CI runners efficiently build analyzer passes, generate absolute test coverage mappings (`lcov`), build complete standalone AOT bundle pipelines and inject out fully deployable native `.tar.gz` Duckbill Artifact releases.

Download Duckbill's production package natively shipped alongside independent C++ local libraries statically linked:

```bash
# Retrieve the package zip file bundle (Swap URL corresponding to your real artifact target branch endpoint)
curl -LO https://github.com/yourrepo/duckbill/releases/latest/download/duckbill-server-linux-amd64.tar.gz

# Extract the looped unzipped container path bounds
mkdir -p /DATA/.local/opt/duckbill
tar -xzf duckbill-server-linux-amd64.tar.gz -C /DATA/.local/opt/duckbill

# Deploy global executable standalone symlink routes natively bypassing full path
ln -s /DATA/.local/opt/duckbill/bin/server /DATA/.local/bin/duckbill

# You're live! 🦆
duckbill
```
