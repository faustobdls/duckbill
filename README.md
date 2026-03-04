# 🦆 Duckbill

Duckbill é uma CLI e Server AI **Privacy-first** escrito nativamente em Dart para alta performance. Ele permite que você execute agentes baseados em Inteligência Artificial remotamente, criando túneis seguros e viabilizando a execução autônoma de comandos na sua máquina (via MCPs - Model Context Protocols) com permissão granular e segurança robusta.

_Leia em outros idiomas: [English](README-en.md), [Español](README-es.md)._

## ✨ Funcionalidades

- **Privacy First:** Menos coleta de dados, você decide e isola a execução da IA.
- **Arquitetura N-N:** Conecte múltiplos terminais (CLIs) a vários servidores.
- **IA Autônoma & Raciocínio Profundo:** Por padrão, utiliza o `gemini-3-flash-preview` com configurações de "Thinking Level" em ALTA (HIGH) capacidade para tomar decisões de comandos operacionais adequadas para a sua máquina hospedeira.
- **Túnel Seguro de WebSocket:** Criptografia de payloads em transição, TLS Pinning e validação HMAC-SHA256 para cada mensagem com tempo de vida TTL.
- **Armazenamento de Senhas Local:** Os PATs (Personal Access Tokens) são isolados e guardados via AES-256-GCM.
- **Storage Otimizado:** Banco de dados SQLite usando interfaces de sistema (FFI C++) com journaling em WAL para sustentar conexões de dezenas de instâncias com alta concorrência.

---

## 🛠️ Alterações do Plano Arquitetural Original

Para adequar o projeto à realidade nativa mais rápida do ecossistema e abstração de FFI, o design original sofreu sutis adaptações arquiteturais:

1. **Estrutura de Pastas Ajustada:** Ao invés das aplicações estarem na subpasta `apps/` e os pacotes todos em um mega pacote core, diluímos os pilares em bibliotecas atômicas (`packages/duckbill_ai`, `packages/duckbill_crypto`, `packages/duckbill_protocol` e `packages/duckbill_storage`) e alocamos a CLI e o Server nas gavetas-raíz `cli/` e `server/`. Isso evitou poluição de injeção de dependências.
2. **Sistema de Compilação:** O plano original previa usar `dart compile exe`. Visto que agora trazemos FFI e Native Assets do SQLite3, a pipeline de compilação migrou para a solução moderna `dart build cli`, que extrai o cache dinâmico (dylib/so) para a mesma pasta do binário.
3. **Poder Autônomo Embutido:** A IA não retorna apenas texto limpo. Ela foi programada para gerar payloads JSON baseados nas permissões requisitadas, enviando os pacotes `.sh`/`bash` ao servidor diretamente preko WebSocket N-N.

---

## 💻 Desenvolvimento Local (Como rodar na sua máquina)

Durante o desenvolvimento, basta executar os códigos primários do Dart com Hot Restart e JIT compilation usando comandos simples na raiz do seu terminal.

1. **Inicie o servidor localmente:**
   Navegue até o servidor, defina sua chave da IA via variável de ambiente, e rode-o na porta padrão (8080):

```bash
cd server
export GEMINI_API_KEY="SUA_CHAVE_GEMINI"
dart run bin/server.dart
```

2. **Gere sua primeira chave PAT de autenticação (Terminal Paralelo):**

```bash
cd cli
dart run bin/cli.dart auth login --token SEU_TOKEN_SECRETO
```

3. **Se comunique através da CLI para o Server via Tunnel:**

```bash
cd cli
dart run bin/cli.dart agent run "Verifique o espaço em disco."
```

---

## 🚀 Compilação e Deploy (Produção)

Não se preocupe com a compilação cruzada na sua máquina de uso diário. Nós preparamos uma esteira de Integração Contínua (CI/CD) usando **GitHub Actions**.

Assim que você realizar um push na branch `main`, os corredores Ubuntu remotos rodarão o analisador, relatórios de testes (`lcov`), gerarão toda a compilação nativa AOT para sua pipeline e fornecerão o **Duckbill Bundle** comprimido em artefatos `.tar.gz`.

Baixe a release do Duckbill com o bundle nativo amarrado com libs C++ de banco:

```bash
# Baixe a versão (Modifique a URL para a correspondente do Repositório)
curl -LO https://github.com/seurepo/duckbill/releases/latest/download/duckbill-server-linux-amd64.tar.gz

# Extraia o banco de dados nativo em loopback
mkdir -p /DATA/.local/opt/duckbill
tar -xzf duckbill-server-linux-amd64.tar.gz -C /DATA/.local/opt/duckbill

# Gere o Symlink do executável final
ln -s /DATA/.local/opt/duckbill/bin/server /DATA/.local/bin/duckbill

# Rode via comando universal!
duckbill
```
