# Projeto Duckbill - Arquitetura e Contexto

## Visão Geral

Duckbill é uma ferramenta de IA via CLI focada em privacidade, execução remota e segurança, operando em uma arquitetura N-N (Client-Server). Consiste em uma CLI (Cliente) e um Agent Server, ambos escritos em Dart. O objetivo é permitir o uso de IAs remotamente com permissões granulares, mantendo dados sensíveis do usuário protegidos.

## Stack Técnica e Padrões

- **Linguagem:** Dart (CLI compilada em binário AOT estático para x86_64 e ARM64; Servidor assíncrono).
- **Comunicação:** WebSockets com TLS Pinning.
- **IAs Suportadas (Base):** Google Gemini e Alibaba DashScope.
- **Armazenamento Servidor:** SQLite (modo WAL habilitado) para a mini-store de MCPs/Skills e hash de tokens.
- **Armazenamento Cliente:** Arquivos JSON locais.

## Autenticação e Autorização (PAT)

- **Formato:** Tokens opacos com prefixo `dbk_` (Duckbill Key) seguidos de string aleatória de alta entropia (ex: `dbk_8xK2lP9qMw...`).
- **Fluxo CLI:** Usuário autentica via comando `duckbill auth login --token <TOKEN>`.
- **Armazenamento Cliente:** O token em texto plano é criptografado via AES-256-GCM e salvo em `~/.duckbill/keys/auth.json`.
- **Armazenamento Servidor:** O servidor armazena apenas o hash SHA-256 do token no SQLite.
- **Handshake WebSocket:** O token é enviado no cabeçalho inicial de upgrade da conexão (`Authorization: Bearer <TOKEN>`).

## Segurança e Payload

- Todo tráfego de túnel possui validação de autenticidade.
- O body das requisições é assinado usando HMAC-SHA256 com um cabeçalho `X-Timestamp`.
- **Regra de Rejeição:** O servidor rejeita qualquer pacote cujo TTL seja maior que 3 minutos (configurável via ENV em segundos).

## Estrutura de Diretórios do Cliente (`~/.duckbill/`)

- `config.json`: Configurações gerais da CLI.
- `rules.json`: Regras estritas de permissão de execução.
- `mcp.json`: Configuração dos Model Context Protocols instalados.
- `remote-skills.json`: Skills disponíveis remotamente.
- `cache/`: Armazenamento de binários/scripts baixados da mini-store (sincronizados via ETag/Hash).
- `keys/`: Arquivos criptografados (AES-GCM) contendo tokens e chaves de API.

## Diretrizes de Código

- Código modular usando injeção de dependência.
- Separação estrita entre Camada de Rede (WS), Criptografia e Orquestração de IA.
- Variáveis sensíveis vêm estritamente de variáveis de ambiente ou da pasta `keys`.
- Métricas: Implementar um wrapper de analytics que atualmente faz apenas `print` no console.
