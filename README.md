# Codex Bedrock Setup

Scripts for running Codex with Amazon Bedrock credentials and model routing.

## Platform notes

The launcher in this repository targets macOS and uses commands such as
`launchctl`, `osascript`, and `open`. Lambda uses its own Linux launcher,
`~/.local/bin/bedrock-codex`, and its own `~/.codex/config.toml` and catalog.

## Required configuration

These scripts do not include a Codex configuration file. Before using them,
create a compatible:

```text
~/.codex/config.toml
```

The configuration must define the Bedrock Runtime provider, the AWS profile
used by your account, and the model you want Codex to use. The scripts expect
an AWS profile named `codex_bedrock` and a source profile named `codex_prod`;
adjust those names in the scripts if your environment uses different names.

## GPT-6 Global models

This Mac excerpt matches the working `~/.codex/config.toml`; keep unrelated
settings already in your file. `model` sets the default, and the catalog
supplies the three choices shown in the model picker.

```toml
model = "global.openai.gpt-6-luna"
model_provider = "amazon-bedrock-runtime"
model_catalog_json = "/Users/lingda/.codex/global-gpt6-models.json"
notify = ["/Users/lingda/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient", "turn-ended"]
model_reasoning_effort = "xhigh"

[model_providers.amazon-bedrock-runtime.aws]
profile = "codex_bedrock"
```

Lambda has its own config and catalog copy. Its region is `us-east-1`, not
`us-region-1`. The current Lambda excerpt is:

```toml
model_provider = "amazon-bedrock-runtime"
model = "global.openai.gpt-6-luna"
model_catalog_json = "/home/lingda/.codex/global-gpt6-models.json"
model_reasoning_effort = "max"
sandbox_mode = "danger-full-access"
approval_policy = "on-request"

[model_providers.amazon-bedrock-runtime]
wire_api = "responses"

[model_providers.amazon-bedrock-runtime.aws]
profile = "codex_prod"
region = "us-east-1"
```

The catalog should contain only these model IDs and display names:

- `global.openai.gpt-6-astra` — `6 Astra (Global)`
- `global.openai.gpt-6-sol` — `6 Sol (Global)`
- `global.openai.gpt-6-luna` — `6 Luna (Global)`

The complete catalog template is [`templates/global-gpt6-models.json`](templates/global-gpt6-models.json).
Copy it to each host's `~/.codex` directory as `global-gpt6-models.json`,
then set `model_catalog_json` to that host's absolute path. Keep independent
copies on the Mac and Lambda; do not symlink one host to the other.

Use the AWS profile configured for that host (`codex_bedrock` on the Mac and
`codex_prod` on Lambda). Keep the region at `us-east-1` for these Global models.

For CLI use, run `bedrock-codex astra`, `bedrock-codex sol`, or
`bedrock-codex luna`. To change the app default, run `bedrock-codex --app astra`,
`bedrock-codex --app sol`, or `bedrock-codex --app luna`. On Lambda, update the
Lambda connection afterward as described below. `bedrock-codex -auth` (or
`--auth`) refreshes credentials without selecting a model.

If CLI model selection works but the Lambda app picker is stale, open Codex
Settings → Connections, select the Lambda connection, and choose **Update**.
Then reconnect the Lambda session. This refreshes the remote app-server; the
CLI command `codex app-server daemon update --from-cli` was not the working
update path in this setup.

You must also have:

- Codex installed and available on `PATH`
- AWS CLI installed
- `macaw-auth` or an equivalent credential-refresh command
- An AWS credential process configured for the `codex_bedrock` profile

## Scripts

```text
scripts/bedrock-codex
```

Authenticates, refreshes the AWS environment, launches Codex CLI, or restarts
the Codex desktop app with `--app`.

```text
scripts/codex-bedrock-creds
```

Implements the AWS `credential_process` and refreshes short-lived credentials
when they are near expiry.

```text
scripts/codex-bedrock-set-interval.sh
```

Changes the macOS LaunchAgent refresh interval:

```bash
bash ~/.codex/scripts/codex-bedrock-set-interval.sh 3000
```

`3000` seconds is 50 minutes.

## Installation

Copy the scripts into the expected local paths:

```bash
mkdir -p ~/.local/bin ~/.codex/scripts
cp templates/global-gpt6-models.json ~/.codex/global-gpt6-models.json
cp scripts/bedrock-codex ~/.local/bin/
cp scripts/codex-bedrock-creds ~/.local/bin/
cp scripts/codex-bedrock-set-interval.sh ~/.codex/scripts/
chmod +x ~/.local/bin/bedrock-codex
chmod +x ~/.local/bin/codex-bedrock-creds
chmod +x ~/.codex/scripts/codex-bedrock-set-interval.sh
```

For Lambda, copy the same catalog file to the Lambda user's own
`~/.codex/global-gpt6-models.json` and use its absolute path in Lambda's
`config.toml`.

Do not commit AWS credentials, Codex authentication files, `.env` files,
session history, logs, or personal configuration files to this repository.
