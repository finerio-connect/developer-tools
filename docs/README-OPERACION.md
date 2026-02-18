# Operacion diaria: OpenCode + GCP

## 1) Cargar modulo (una sola vez en tu rc)

En `~/.zshrc` o `~/.bashrc`:

```bash
[[ -f "$HOME/.config/opencode-gcp/shell/gcp-tools.sh" ]] && source "$HOME/.config/opencode-gcp/shell/gcp-tools.sh"
```

Luego:

```bash
source ~/.zshrc   # o source ~/.bashrc
```

## 2) Activar proyecto

```bash
gcp-list
use-gcp developer-tools
use-gcp enrichment-dev
use-gcp cortex-dev
```

`use-gcp` hace:

- carga `~/.config/gcp-env/<name>.env`
- exporta `PROJECT_ID`, `LOCATION`, `GOOGLE_APPLICATION_CREDENTIALS`
- actualiza `gcloud config set project`
- apunta `credentials/active/finerio-key.json` a la key del entorno
- sincroniza `provider.finerio.options.project/location` en `opencode.json` (si hay `jq`)

## 3) Dónde van las credenciales

- Key activa usada por OpenCode:
  - `~/.config/opencode-gcp/credentials/active/finerio-key.json`
- Key por proyecto:
  - `~/.config/opencode-gcp/credentials/projects/<mapped-project>/finerio-key.json`

Ejemplo:

```bash
cp ./finerio-key.json ~/.config/opencode-gcp/credentials/projects/enrichment-dev/finerio-key.json
use-gcp enrichment-dev
```

## 4) Validar OpenCode

```bash
opencode-gcp --show-config
opencode-gcp --doctor
```

## 5) Proyectos mapeados

- `multiclient-dev` -> `multiclient-dev`
- `enrichment-dev` -> `enrichment-dev-485816`
- `developer-tools` -> `developer-tools-482502`
- `data-dev` -> `data-dev-487014`
- `finerio-labs` -> `finerio-labs`
- `cortex-dev` -> `cortex-dev-480819`
- `multiclient-demo` -> `multiclient-demo`
- `pfm-dev` -> `pfm-dev-485816`
- `cortex-prod` -> `cortex-prod-481416`

## 6) Troubleshooting

- `Env file not found`: revisa `~/.config/gcp-env/<name>.env`
- `Key file not found`: copia la key al path del entorno
- `placeholder` en doctor: reemplaza `credentials/active/finerio-key.json` por key real
