# 🦆 Duckbill

Duckbill es una CLI y Servidor de IA **Privacy-first** escrito de forma nativa en Dart enfocado en el alto rendimiento. Permite ejecutar agentes autónomos basados en Inteligencia Artificial de forma remota configurando estrictos túneles seguros para concretar operaciones automatizadas de su sistema local utilizando Model Context Protocols (MCPs) bajo niveles de control de permisos de total granularidad.

_Léelo en otros idiomas: [Português](README.md), [English](README-en.md)._

## ✨ Características

- **Privacy First:** Menor impacto en la huella de rastreo, usted posee control absoluto mientras aisla las ejecuciones completas de su agente automatizado.
- **Arquitectura N-N:** Interconecte sin esfuerzos múltiples puntos cliente (CLIs) hasta concurrir servidores simultáneos por el socket.
- **Razonamiento Profundo de IA Autónoma:** Configurado nativamente por su defecto integrando el `gemini-3-flash-preview` amarrado tras el "Thinking Level" (Nivel de Pensamiento) con configuraciones en capa ALTA. Las decisiones y shell commands son tomadas analizando el SO primario antes de responder de vuelta por MCP.
- **Tunneling de Websocket Criptográficos Seguros:** Encriptación de tráfico integral de enrutamiento TLS Pinning construyendo validador clave simétrico HMAC-SHA256 al portador individual reajustando un corto lapso (TTL) de límite cronometrado en sus flujos.
- **Resguardo Local Físico de Acceso PAT:** Autenticaciones token selladas envueltas dentro del esquema simétrico AES-256-GCM.
- **Respaldo Adaptativo C++ FFI:** Soporte al motor SQLite aprovechando la capa dinámica base del C++ (FFI) con configuraciones WAL de Bitácora para dar un robusto ecosistema asíncrono N-N sin choques del filesystem.

---

## 🛠️ Alteraciones en el Plan Original del Arquitecto

A modo de estructurar asertivamente y aprovechar lo último de un ecosistema en transiciones hacia los estándares FFI y el empaquetamiento optimizado, pequeños reajustamientos sucedieron lejos de los conceptos fundacionales abstractos:

1. **Remodelación Arquitectural Raíz:** Evadiendo concentrar y fusionar monolíticamente subbloques enormes sobre la carpeta madre de binarios, se modularizó atómicamente la estructura sobre el bloque nativo compartimentado (`packages/duckbill_ai`, `packages/duckbill_crypto`, `packages/duckbill_protocol` y `packages/duckbill_storage`). Se elevó la propia interfaz cli particular y el servidor primario al nivel super-raíz de forma separada sobre sus respectivas ubicaciones (`cli/` y `server/`) alejándolos de polución abstractiva pesada.
2. **Infraestructura de Inyección y Compilación:** Originalmente, las tareas se ordenaban por encima de la invocación standard del compilador de ejecutable (`dart compile exe`). Con los recientes puentes nativos directos implementados de FFI que ligan las dependencias `.so` en C++ del motor SQLite dinámicamente, este enfoque se viró a un más complejo armazón local implementado modernamente como bloque (`dart build cli`).
3. **Poder Autonómico Funcional Directo Embebido:** Diferenciándose del inicial flujo planeado simplemente de chatear por texto simple, la IA actúa ejecutivamente parseando órdenes emitiendo códigos empaquetados como estructuras shell `.sh` y `.bash` regresadas bajo variables controladas por la CLI y expuestas netamente hacia el SO a nivel Servidor.

---

## 💻 Desarrollo Local (Cómo usar en su Máquina Local)

A lo largo del desarrollo natural diario en código Dart, interactuar contra una JIT (compiladora local interactiva) basta plenamente con ligeros tiempos de despliegue sobre su consola local en modo hot-restart.

1. **Inicie el servidor autónomo directamente en puerto local:**
   Acceda internamente pasando la directriz API generada a nivel base de consola (export) desplegándose tras el puerto estándar por defecto (8080):

```bash
cd server
export GEMINI_API_KEY="COLOQUE_SU_CLAVE_AI_AQUI"
dart run bin/server.dart
```

2. **Acuerde localmente generar su terminal Paralelo por autenticación Local:**

```bash
cd cli
dart run bin/cli.dart auth login --token EL_TOKEN_SECRETO_QUE_USTED_DESEE
```

3. **Inicie interacción con ejecución remota a Servidor vía Tunnel CLI enrutado:**

```bash
cd cli
dart run bin/cli.dart agent run "Dime, ¿cuánto espacio libre dispongo en mí disco de servidor?"
```

---

## 🚀 Despliegue en Producción y Compilación Optimizada Cruzada (CI/CD)

Evite de primera mano lidiar a nivel de binarios armando ejecutables AOT manuales bajo cruce arquitectónico por un sistema OS ajeno. Encomiende asertivamente el peso pesado a través a nuestra continua automatización continua alojada transparentemente tras **GitHub Actions**.

Día a día tras cada "push" final de las funciones estables integradas en la matriz principal `main`, las granjas integradas Ubuntu desplegarán análisis semánticos rigurosos nativos, generador exacto y porcentual para trazador testeado cruzado final (`lcov`), conformando una construcción íntegra armando archivos puros nativos dinámicamente comprimidos adjuntos tras una terminación artefacto `.tar.gz` exportada de lanzamiento (Release).

Mueva su versión de Producción extraída comprimida atada fuertemente a las bases instaladas requeridas del motor C++ (SQLite3):

```bash
# Obtenga velozmente su versión artefacto liberada más cercana comprimida tar.gz (Actualice la respectiva URL fuente a la particular generada a un repóstorio específico original)
curl -LO https://github.com/surepositorio/duckbill/releases/latest/download/duckbill-server-linux-amd64.tar.gz

# Genere el bucle contenedora aislando en /opt su des-compactamiento
mkdir -p /DATA/.local/opt/duckbill
tar -xzf duckbill-server-linux-amd64.tar.gz -C /DATA/.local/opt/duckbill

# Ajuste globalmente el acceso al ejecutable mediante puente symlink local (sin ruteos tediosos PATH global)
ln -s /DATA/.local/opt/duckbill/bin/server /DATA/.local/bin/duckbill

# Listo a nivel binario. Corra el autónomo! 🦆
duckbill
```
