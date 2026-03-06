# 🦆 Duckbill

Duckbill é uma CLI e Server AI **Privacy-first** escrito nativamente em Dart para alta performance. Ele permite que você execute agentes baseados em Inteligência Artificial remotamente, com uma arquitetura WebSocket segura N-N, execução **local** de sugestões da IA (como o Claude Code), menu interativo no terminal e pacotes reutilizáveis seguindo **SOLID** e **Clean Architecture**.

_Leia em outros idiomas: [English](README-en.md), [Español](README-es.md)._

---

## ✨ Funcionalidades

- **Privacy First:** Menos coleta de dados — você decide onde e como a IA é executada.
- **Arquitetura N-N:** Conecte múltiplos clientes a vários servidores via WebSocket.
- **Execução Local de Sugestões:** O cliente recebe sugestões da IA e as executa **na sua máquina** com aprovação prévia — assim como o Claude Code.
- **Configuração Remota de Modelo:** O servidor empurra modelo/provider ao cliente via frame `config` após o handshake. O cliente não precisa saber de antemão qual IA usar.
- **Menu Interativo no Console:** Execute `duckbill` sem argumentos para entrar em modo interativo com menu numerado e chat de IA.
- **Protocolo de Mensagens Tipado:** Frames JSON estruturados (`prompt`, `response`, `suggestion`, `execution_result`, `config`, `stream_end`, `error`) para roteamento preciso.
- **Túnel WebSocket Seguro:** Bearer Token no handshake + HMAC-SHA256 com TTL de 180s.
- **Armazenamento Local de Credenciais:** PATs criptografados com AES-256-GCM em `~/.duckbill/keys/`.
- **Banco de Dados SQLite:** WAL mode, FFI nativo, alta concorrência.
- **Cobertura de Testes ≥ 90%:** Todos os pacotes com suites de testes abrangentes.

---

## 🏗️ Arquitetura (SOLID + Clean Architecture)

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

### Pacotes

| Pacote | Responsabilidade |
|---|---|
| `duckbill_crypto` | Criptografia AES-256-GCM, armazenamento de PATs |
| `duckbill_storage` | SQLite (WAL), configuração JSON |
| `duckbill_protocol` | WebSocket, HMAC-SHA256, `MessageFrame`, `MessageRouter`, `ClientRegistry` |
| `duckbill_ai` | Adaptador Gemini, `FunctionParser` |
| `duckbill_agent` | `AgentSession`, `LocalExecutor`, `ExecutionGate`, `SuggestionParser` |
| `duckbill_console` | Menu interativo, chat TUI, estilos ANSI |

---

## 💻 Como usar

### Modo Interativo (Novo!)

Execute sem argumentos para o menu:

```bash
duckbill
```

O menu oferece:
- **Interactive AI Session** — chat multi-turn com aprovação de sugestões por sugestão
- **Run Single Prompt** — envia um prompt e sai
- **Save Auth Token** — salva seu PAT de forma criptografada
- **Start Server** — inicia o servidor WebSocket
- **Version Info** / **Update**

### Linha de Comando

#### 1. Salve seu token de autenticação

```bash
duckbill auth login --token SEU_TOKEN_SECRETO
```

#### 2. Inicie o servidor

```bash
export GEMINI_API_KEY="SUA_CHAVE_GEMINI"
duckbill server start --port 8080
```

#### 3. Sessão interativa (estilo Claude Code)

```bash
# Com aprovação manual de cada sugestão:
duckbill agent interactive

# Com auto-aprovação (CI/pipelines):
duckbill agent interactive --auto-approve
```

#### 4. Prompt único

```bash
duckbill agent run "Verifique o espaço em disco."
duckbill agent run --auto-approve "Liste os processos em execução."
```

---

## 🔐 Segurança

| Camada | Mecanismo |
|---|---|
| Handshake WebSocket | Bearer Token no cabeçalho `Authorization` |
| Payload | Assinatura HMAC-SHA256 + TTL 180s |
| Armazenamento local | AES-256-GCM em `~/.duckbill/keys/auth.json` |
| Aprovação de execução | Gate interativo (usuário aprova cada sugestão) |

---

## 📦 Protocolo de Mensagens

Toda comunicação usa frames JSON estruturados:

```json
// Cliente → Servidor
{"type": "prompt",           "payload": {"text": "..."}, "ts": 1234567890}

// Servidor → Cliente (após handshake)
{"type": "config",           "payload": {"model": "gemini-3", "provider": "gemini"}, "ts": ...}

// Servidor → Cliente (resposta da IA)
{"type": "suggestion",       "payload": {"command": "ls -la", "explanation": "..."}, "ts": ...}
{"type": "response",         "payload": {"text": "..."}, "ts": ...}
{"type": "stream_end",       "payload": {}, "ts": ...}

// Cliente → Servidor (resultado da execução local)
{"type": "execution_result", "payload": {"exit_code": 0, "stdout": "...", "stderr": ""}, "ts": ...}
```

---

## 🚀 Compilação e Deploy

A pipeline CI/CD (GitHub Actions) compila para múltiplas plataformas ao fazer push de uma tag `v*`:

```bash
git tag v1.0.0 && git push --tags
```

Plataformas: Linux x86_64/ARM64, macOS Intel/Apple Silicon, Windows x86_64.

Para instalar manualmente:

```bash
curl -LO https://github.com/SEU_REPO/duckbill/releases/latest/download/duckbill-cli-linux-amd64.tar.gz
mkdir -p ~/.local/opt/duckbill && tar -xzf duckbill-cli-linux-amd64.tar.gz -C ~/.local/opt/duckbill
ln -s ~/.local/opt/duckbill/bin/cli ~/.local/bin/duckbill
```

---

## 🧪 Testes

```bash
# Rodar todos os testes
for dir in packages/duckbill_crypto packages/duckbill_storage packages/duckbill_protocol \
           packages/duckbill_ai packages/duckbill_agent packages/duckbill_console server cli; do
  (cd $dir && dart test)
done
```

Cobertura alvo: **≥ 90%** por pacote.

---

## 🛠️ Alterações do Plano Arquitetural Original

1. **Execução Local:** Ao invés do servidor executar comandos no servidor, o **cliente** recebe sugestões e as executa localmente, com aprovação prévia. O servidor atua como roteador/orquestrador, não como executor.
2. **Protocolo Tipado:** Todos os frames WebSocket agora carregam um campo `type` + `payload` JSON, eliminando parsing frágil de strings.
3. **Novos Pacotes:** `duckbill_agent` (execução local + gate de aprovação) e `duckbill_console` (menu TUI + estilos ANSI).
4. **SOLID no Servidor:** `DuckbillServer` delegou responsabilidades para `ClientHandler`, `AiRequestHandler`, `ConfigSyncHandler`, `ClientRegistry` e `MessageRouter`.
5. **Menu Interativo:** A CLI detecta ausência de argumentos e exibe um menu interativo estilo TUI.
