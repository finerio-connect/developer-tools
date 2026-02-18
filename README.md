# OpenCode + GCP Installer (perfil unico Finerio)

Este setup instala OpenCode y configura un unico `opencode-gcp`.

Reglas:

- solo existe un `opencode-gcp`
- se usa un perfil unico de credenciales GCP
- la configuracion de OpenCode es unica e independiente del proyecto

## Requisitos

- macOS o Linux (incluye WSL)
- `bash`
- `curl`
- `gcloud` (opcional, recomendado)

## Instalacion

```bash
chmod +x install-opencode-gcp.sh
./install-opencode-gcp.sh --region us-central1
```

Opciones:

- `--region`: region para Vertex AI (`global`, `us-central1`, etc.)
- `--force`: reescribe archivos de perfil/config base (genera backup de `opencode.json`)

## Proyectos mapeados (finerio.mx)

- `multiclient-dev` -> `multiclient-dev`
- `enrichment-dev` -> `enrichment-dev-485816`
- `developer-tools` -> `developer-tools-482502`
- `data-dev` -> `data-dev-487014`
- `finerio-labs` -> `finerio-labs`
- `cortex-dev` -> `cortex-dev-480819`
- `multiclient-demo` -> `multiclient-demo`
- `pfm-dev` -> `pfm-dev-485816`
- `cortex-prod` -> `cortex-prod-481416`

## Estandar de estructura (post-instalacion)

```text
~/.config/opencode-gcp/
├── opencode.env
├── profiles/
│   └── developer-tools.env
└── credentials/
    ├── active/
    │   └── finerio-key.json
    └── projects/
        ├── projects-map.txt
        ├── multiclient-dev/
        │   ├── project-id.txt
        │   └── finerio-key.json
        ├── enrichment-dev/
        ├── developer-tools/
        ├── data-dev/
        ├── finerio-labs/
        ├── cortex-dev/
        ├── multiclient-demo/
        ├── pfm-dev/
        └── cortex-prod/

~/.config/opencode/
└── opencode.json
```

## Flujo recomendado de credenciales

1. Guarda cada key en su carpeta estandar:

```bash
cp ./finerio-key.json ~/.config/opencode-gcp/credentials/projects/cortex-dev/finerio-key.json
```

2. Activa la key que quieres usar en OpenCode (ruta unica):

```bash
ln -sfn ~/.config/opencode-gcp/credentials/projects/cortex-dev/finerio-key.json \
  ~/.config/opencode-gcp/credentials/active/finerio-key.json
```

Alternativa sin symlink:

```bash
cp ~/.config/opencode-gcp/credentials/projects/cortex-dev/finerio-key.json \
  ~/.config/opencode-gcp/credentials/active/finerio-key.json
```

## Configuracion base de OpenCode

El instalador genera `~/.config/opencode/opencode.json` con tu base `finerio`:

- `provider.finerio.npm = @ai-sdk/google-vertex`
- modelos `finerio/fast` y `finerio/deep`
- `theme = matrix`
- MCP browser local con `node <ruta chrome-devtools-mcp>`

Tambien crea `~/.config/opencode-gcp/opencode.env` (ajustes globales adicionales).

Variables utiles antes de instalar:

- `OPENCODE_GCP_VERTEX_PROJECT_ID` (default: `developer-tools-482502`)
- `OPENCODE_GCP_PROJECT_ID` (default: mismo valor anterior)
- `OPENCODE_GCP_BROWSER_MCP_PATH` (ruta del MCP browser)

## Uso rapido

```bash
opencode-gcp --doctor
opencode-gcp --show-config
opencode-gcp
opencode-gcp -- -m google/gemini-2.5-pro
```

Si `~/.local/bin` no esta en `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Documentacion extra

- `docs/README-OPERACION.md`
