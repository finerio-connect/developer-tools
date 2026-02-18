# Operacion diaria: OpenCode + GCP (perfil unico)

Este setup usa un unico `opencode-gcp` con perfil fijo y config base unica.

## 1) Verificar estado

```bash
opencode-gcp --doctor
opencode-gcp --show-config
```

`--doctor` valida:

- binario `opencode`
- perfil `~/.config/opencode-gcp/profiles/developer-tools.env`
- credencial activa `~/.config/opencode-gcp/credentials/active/finerio-key.json`

## 2) Catalogo de proyectos mapeados

Referencias reales (name -> project_id):

- `multiclient-dev` -> `multiclient-dev`
- `enrichment-dev` -> `enrichment-dev-485816`
- `developer-tools` -> `developer-tools-482502`
- `data-dev` -> `data-dev-487014`
- `finerio-labs` -> `finerio-labs`
- `cortex-dev` -> `cortex-dev-480819`
- `multiclient-demo` -> `multiclient-demo`
- `pfm-dev` -> `pfm-dev-485816`
- `cortex-prod` -> `cortex-prod-481416`

El instalador también guarda este catálogo en:

- `~/.config/opencode-gcp/credentials/projects/projects-map.txt`

## 3) Estandar para guardar keys

Usa siempre esta estructura:

- `~/.config/opencode-gcp/credentials/projects/<mapped-project>/finerio-key.json`

Ejemplo:

```bash
cp ./finerio-key.json ~/.config/opencode-gcp/credentials/projects/pfm-dev/finerio-key.json
```

## 4) Activar una key para OpenCode

OpenCode siempre usa una ruta activa unica:

- `~/.config/opencode-gcp/credentials/active/finerio-key.json`

Activacion recomendada (symlink):

```bash
ln -sfn ~/.config/opencode-gcp/credentials/projects/pfm-dev/finerio-key.json \
  ~/.config/opencode-gcp/credentials/active/finerio-key.json
```

Alternativa (copia):

```bash
cp ~/.config/opencode-gcp/credentials/projects/pfm-dev/finerio-key.json \
  ~/.config/opencode-gcp/credentials/active/finerio-key.json
```

## 5) Configuracion unica de OpenCode

Archivo principal base:

- `~/.config/opencode/opencode.json`

Archivo de ajustes globales adicionales:

- `~/.config/opencode-gcp/opencode.env`

El `opencode.json` que crea el instalador incluye provider `finerio`, modelos `fast/deep`, tema `matrix` y MCP browser local.

## 6) Ejecutar OpenCode

```bash
opencode-gcp
opencode-gcp -- -m google/gemini-2.5-pro
```

## 7) Ajustes recomendados

- Si cambia el proyecto Vertex, actualiza `provider.finerio.options.project` en `~/.config/opencode/opencode.json`.
- Si cambia la region, actualiza `provider.finerio.options.location` en `~/.config/opencode/opencode.json`.
- Si cambia la ruta del MCP browser, actualiza `mcp.browser.command` en `~/.config/opencode/opencode.json`.

## 8) Troubleshooting rapido

- Error `placeholder` en credenciales:
  - Reemplaza `~/.config/opencode-gcp/credentials/active/finerio-key.json` con una key real.
- Error `No existe GOOGLE_APPLICATION_CREDENTIALS`:
  - Verifica que exista el archivo activo.
- Error de permisos GCP:
  - Verifica IAM del service account de esa key.
