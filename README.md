# 🦆 Duckbill

Duckbill is a privacy-first, blazing-fast AI Agent CLI and Server built in Dart. It allows you to run AI agents remotely, connect multiple API providers, and execute Model Context Protocols (MCPs) with granular, user-controlled permissions.

## ✨ Features

- **Privacy First:** Minimal data collection. You are always in control of what the AI can see and execute.
- **N-N Architecture:** Connect multiple CLIs to multiple servers seamlessly.
- **High-Performance:** Compiled ahead-of-time (AOT) to single static binaries. Runs anywhere, even on Alpine Linux.
- **Secure Tunneling:** WebSocket communication with TLS Pinning, HMAC-SHA256 payload signing, and strict 3-minute TTL requests.
- **Token Authentication:** Secure Personal Access Tokens (PATs) starting with `dbk_`.
- **Mini-Store:** Built-in SQLite-powered cache for sharing and installing remote skills and MCPs.

## 🚀 Installation

Download the latest binary for your architecture (ARM64 or x86_64) from the [Releases](https://github.com/youruser/duckbill/releases) page.

```bash
# Example for Linux/macOS
curl -LO [https://github.com/youruser/duckbill/releases/latest/download/duckbill-linux-amd64](https://github.com/youruser/duckbill/releases/latest/download/duckbill-linux-amd64)
chmod +x duckbill-linux-amd64
sudo mv duckbill-linux-amd64 /usr/local/bin/duckbill
```

## 🛠️ Usage

Authentication
Login securely to a Duckbill Server using your token:

```bash
duckbill auth login --token dbk_YOUR_TOKEN_HERE
```

Tokens are encrypted locally using AES-256-GCM and stored in ~/.duckbill/keys/.

Running the Server
Start a lightweight, high-concurrency Duckbill server:

```bash
duckbill server start --port 8080
```

## 📂 Configuration Structure

Duckbill keeps your environment clean by isolating configurations in ~/.duckbill/:

- config.json: General CLI settings.
- rules.json: Strict execution permissions.
- mcp.json & remote-skills.json: Installed capabilities.
- cache/: Downloaded remote assets.

## 🤝 Contributing

Duckbill is Open Source. PRs are welcome! See our contribution guidelines for details on compiling the Dart source code.

---

### 3. Recomendações de Skills e MCPs

Salve como `skills-and-mcps.md` para instruir o agente sobre as ferramentas iniciais a serem implementadas.

```markdown
# Catálogo Inicial - Duckbill Mini-Store

## Model Context Protocols (MCPs)

1. **`duckbill-sqlite-mcp`**: Permite que a IA consulte e analise bancos de dados SQLite locais do usuário de forma segura, mediante aprovação explícita.
2. **`duckbill-fs-mcp`**: Acesso controlado ao sistema de arquivos. Regra estrita: leitura restrita ao diretório de trabalho atual (PWD), proibido acesso à raiz do sistema ou arquivos de sistema (ex: `/etc`).
3. **`duckbill-github-mcp`**: Integração com API do GitHub para ler PRs, issues e repositórios diretamente, evitando a necessidade de clonar o código localmente.

## Core Skills (Ferramentas Nativas)

1. **`shell_execute`**: Skill base para execução de comandos no terminal. Requer confirmação explícita do usuário (Y/n) no console da CLI antes de enviar o retorno pelo túnel, a menos que o comando esteja na _whitelist_ do `~/.duckbill/rules.json`.
2. **`fetch_url`**: Skill que baixa o conteúdo de uma URL, converte o HTML para Markdown puro, removendo tags desnecessárias, e alimenta o contexto da IA via túnel.
3. **`install_mcp`**: Permite à IA consultar o SQLite da mini-store no servidor e sugerir ao usuário a instalação de um novo MCP sob demanda via _lazy load_ para a pasta `~/.duckbill/cache/`.
```

### 4. Estrutura de Pastas Base (Monorepo Dart)

Forneça isso ao agente para que ele saiba como estruturar os pacotes internamente para reaproveitamento de código entre a CLI e o Servidor.

```
duckbill/
├── .github/
│   └── workflows/
│       └── build.yml          # Actions para compilar ARM64/x86_64
├── packages/
│   ├── duckbill_core/         # Lógica compartilhada: Criptografia, HMAC, Models, Auth
│   └── duckbill_protocol/     # Definição do WebSocket, Handshake e Túnel
├── apps/
│   ├── duckbill_cli/          # Aplicação CLI (Injeção de dependência, UI de terminal)
│   └── duckbill_server/       # Aplicação Servidor (Conexão com IA, SQLite, Gerenciamento N-N)
├── .duckbill-context.md
└── README.md
```
