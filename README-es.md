# 🦆 Duckbill

Duckbill es una CLI y Servidor de IA **Privacy-first** escrito nativamente en Dart para alto rendimiento. Permite ejecutar agentes de Inteligencia Artificial de forma remota con una arquitectura WebSocket segura N-N, ejecución **local** de sugerencias (como Claude Code), menú interactivo en la terminal y paquetes reutilizables siguiendo principios **SOLID** y **Clean Architecture**.

_Leer en otros idiomas: [Português](README.md), [English](README-en.md)._

---

## ✨ Características

- **Privacy First:** Tú decides dónde y cómo corre la IA — mínima recolección de datos.
- **Arquitectura N-N:** Conecta múltiples clientes a múltiples servidores vía WebSocket.
- **Ejecución Local de Sugerencias:** El cliente recibe sugerencias de la IA y las ejecuta **en tu máquina** con aprobación por sugerencia — igual que Claude Code u OpenClaw.
- **Configuración Remota de Modelo:** El servidor envía modelo/proveedor al cliente via frame `config` tras el handshake WebSocket. El cliente no necesita conocer la configuración de IA de antemano.
- **Menú Interactivo en Consola:** Ejecuta `duckbill` sin argumentos para entrar en modo interactivo con menú numerado e interfaz de chat con IA.
- **Protocolo de Mensajes Tipado:** Frames JSON estructurados (`prompt`, `response`, `suggestion`, `execution_result`, `config`, `stream_end`, `error`) para enrutamiento preciso.
- **Túnel WebSocket Seguro:** Bearer Token en el handshake + HMAC-SHA256 con TTL de 180s.
- **Almacenamiento Local de Credenciales:** PATs cifrados con AES-256-GCM en `~/.duckbill/keys/`.
- **Base de Datos SQLite:** Modo WAL, bindings FFI nativos, alta concurrencia.
- **Cobertura de Tests ≥ 90%:** Suites de tests exhaustivas en todos los paquetes.

---

## 🏗️ Arquitectura (SOLID + Clean Architecture)

```
┌─────────────────────────────────────────────────────┐
│               Capa de Presentación                  │
│         CLI (duckbill) · Menú Interactivo           │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│         Capa de Aplicación / Casos de Uso           │
│       AgentSession · InteractiveRunner              │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
┌──────────▼──────────┐  ┌────────▼───────────────────┐
│   Capa de Dominio   │  │  Capa de Infraestructura    │
│  AiSuggestion       │  │  duckbill_crypto  (AES-GCM) │
│  ExecutionGate      │  │  duckbill_storage (SQLite)  │
│  LocalExecutor      │  │  duckbill_protocol (WS+HMAC)│
│  MessageFrame       │  │  duckbill_ai      (Gemini)  │
└─────────────────────┘  └────────────────────────────┘
```

### Paquetes

| Paquete | Responsabilidad |
|---|---|
| `duckbill_crypto` | Cifrado AES-256-GCM, almacenamiento de PATs |
| `duckbill_storage` | SQLite (WAL), configuración JSON |
| `duckbill_protocol` | WebSocket, HMAC-SHA256, `MessageFrame`, `MessageRouter`, `ClientRegistry` |
| `duckbill_ai` | Adaptador Gemini, `FunctionParser` |
| `duckbill_agent` | `AgentSession`, `LocalExecutor`, `ExecutionGate`, `SuggestionParser` |
| `duckbill_console` | Menú interactivo, chat TUI, estilos ANSI |

---

## 💻 Uso

### Modo Interactivo (¡Nuevo!)

Ejecuta sin argumentos para ver el menú:

```bash
duckbill
```

Opciones del menú:
- **Interactive AI Session** — chat multi-turno con aprobación por sugerencia
- **Run Single Prompt** — envía un prompt y sale
- **Save Auth Token** — guarda tu PAT cifrado
- **Start Server** — inicia el servidor WebSocket
- **Version Info** / **Update**

### Línea de Comandos

#### 1. Guarda tu token de autenticación

```bash
duckbill auth login --token TU_TOKEN_SECRETO
```

#### 2. Inicia el servidor

```bash
export GEMINI_API_KEY="TU_CLAVE_GEMINI"
duckbill server start --port 8080
```

#### 3. Sesión interactiva (estilo Claude Code)

```bash
# Aprobación manual de cada sugerencia:
duckbill agent interactive

# Auto-aprobación (CI/pipelines automatizados):
duckbill agent interactive --auto-approve
```

#### 4. Prompt único

```bash
duckbill agent run "Verificar el espacio en disco."
duckbill agent run --auto-approve "Listar procesos en ejecución."
```

---

## 🔐 Seguridad

| Capa | Mecanismo |
|---|---|
| Handshake WebSocket | Bearer Token en cabecera `Authorization` |
| Payload | Firma HMAC-SHA256 + TTL 180s |
| Almacenamiento local | AES-256-GCM en `~/.duckbill/keys/auth.json` |
| Aprobación de ejecución | Gate interactivo (usuario aprueba cada sugerencia) |

---

## 📦 Protocolo de Mensajes

Toda la comunicación usa frames JSON estructurados:

```json
// Cliente → Servidor
{"type": "prompt",           "payload": {"text": "..."}, "ts": 1234567890}

// Servidor → Cliente (tras handshake)
{"type": "config",           "payload": {"model": "gemini-3", "provider": "gemini"}, "ts": ...}

// Servidor → Cliente (respuesta IA)
{"type": "suggestion",       "payload": {"command": "ls -la", "explanation": "..."}, "ts": ...}
{"type": "response",         "payload": {"text": "..."}, "ts": ...}
{"type": "stream_end",       "payload": {}, "ts": ...}

// Cliente → Servidor (resultado de ejecución local)
{"type": "execution_result", "payload": {"exit_code": 0, "stdout": "...", "stderr": ""}, "ts": ...}
```

---

## 🚀 Compilación y Despliegue

El pipeline CI/CD (GitHub Actions) compila para múltiples plataformas al hacer push de una etiqueta `v*`:

```bash
git tag v1.0.0 && git push --tags
```

Plataformas: Linux x86_64/ARM64, macOS Intel/Apple Silicon, Windows x86_64.

Instalación manual:

```bash
curl -LO https://github.com/TU_REPO/duckbill/releases/latest/download/duckbill-cli-linux-amd64.tar.gz
mkdir -p ~/.local/opt/duckbill && tar -xzf duckbill-cli-linux-amd64.tar.gz -C ~/.local/opt/duckbill
ln -s ~/.local/opt/duckbill/bin/cli ~/.local/bin/duckbill
```

---

## 🧪 Tests

```bash
for dir in packages/duckbill_crypto packages/duckbill_storage packages/duckbill_protocol \
           packages/duckbill_ai packages/duckbill_agent packages/duckbill_console server cli; do
  (cd $dir && dart test)
done
```

Cobertura objetivo: **≥ 90%** por paquete.

---

## 🛠️ Cambios Respecto al Plan Arquitectónico Original

1. **Ejecución Local:** En lugar de que el servidor ejecute comandos en el servidor, el **cliente** recibe sugerencias y las ejecuta localmente, con aprobación por sugerencia. El servidor actúa como enrutador/orquestador, no como ejecutor.
2. **Protocolo Tipado:** Todos los frames WebSocket llevan ahora un campo `type` + `payload` JSON, eliminando el frágil parsing de strings.
3. **Nuevos Paquetes:** `duckbill_agent` (ejecución local + gate de aprobación) y `duckbill_console` (menú TUI + estilos ANSI).
4. **SOLID en el Servidor:** `DuckbillServer` delega en `ClientHandler`, `AiRequestHandler`, `ConfigSyncHandler`, `ClientRegistry` y `MessageRouter`.
5. **Menú Interactivo:** La CLI detecta la ausencia de argumentos y presenta un menú interactivo estilo TUI.
