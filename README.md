# OpenCode + GCP Installer (perfil unico Finerio)

Este setup instala OpenCode, genera un wrapper `opencode-gcp` y un modulo shell editable.

## Instalacion

```bash
chmod +x install-opencode-gcp.sh
./install-opencode-gcp.sh --region us-central1
```

Opciones:

- `--region`: region por defecto para Vertex AI
- `--force`: regenera perfil/config/modulo/envs (backup de `opencode.json`)

## Estructura generada

```text
~/.config/opencode-gcp/
├── opencode.env
├── profiles/developer-tools.env
├── credentials/
│   ├── active/finerio-key.json
│   └── projects/
│       ├── projects-map.txt
│       ├── multiclient-dev/
│       ├── enrichment-dev/
│       ├── developer-tools/
│       ├── data-dev/
│       ├── finerio-labs/
│       ├── cortex-dev/
│       ├── multiclient-demo/
│       ├── pfm-dev/
│       └── cortex-prod/
└── shell/gcp-tools.sh

~/.config/gcp-env/
├── multiclient-dev.env
├── enrichment-dev.env
├── developer-tools.env
├── data-dev.env
├── finerio-labs.env
├── cortex-dev.env
├── multiclient-demo.env
├── pfm-dev.env
└── cortex-prod.env

~/.config/opencode/
└── opencode.json
```

## Modulo para ~/.zshrc o ~/.bashrc

Agrega solo esta linea una vez:

```bash
[[ -f "$HOME/.config/opencode-gcp/shell/gcp-tools.sh" ]] && source "$HOME/.config/opencode-gcp/shell/gcp-tools.sh"
```

Despues de eso, si cambias el modulo no necesitas volver a editar `.zshrc`.

## Comandos del modulo

- `gcp-list`: lista los entornos disponibles (`~/.config/gcp-env/*.env`)
- `use-gcp <mapped-project>`: activa proyecto/key, actualiza `gcloud` y sincroniza `opencode.json` (si hay `jq`)

Ejemplos:

```bash
gcp-list
use-gcp enrichment-dev
use-gcp cortex-dev
```

## Proyectos mapeados (name -> project_id)

- `multiclient-dev` -> `multiclient-dev`
- `enrichment-dev` -> `enrichment-dev-485816`
- `developer-tools` -> `developer-tools-482502`
- `data-dev` -> `data-dev-487014`
- `finerio-labs` -> `finerio-labs`
- `cortex-dev` -> `cortex-dev-480819`
- `multiclient-demo` -> `multiclient-demo`
- `pfm-dev` -> `pfm-dev-485816`
- `cortex-prod` -> `cortex-prod-481416`

## Uso de OpenCode

```bash
opencode-gcp --doctor
opencode-gcp --show-config
opencode-gcp
```

`opencode-gcp` siempre usa la key activa `~/.config/opencode-gcp/credentials/active/finerio-key.json` y no depende de activar `gcloud`.

## Documentacion extra

- `docs/README-OPERACION.md`
