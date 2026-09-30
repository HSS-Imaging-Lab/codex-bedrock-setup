# Codex Bedrock Setup

Scripts for running Codex with Amazon Bedrock credentials and model routing.

## Platform notes

The launcher in this repository targets macOS and uses commands such as
`launchctl`, `osascript`, and `open`. Lambda uses its own Linux launcher,
`~/.local/bin/bedrock-codex`, and its own `~/.codex/config.toml` and catalog.
The refresh interval helpers are platform-specific:

- **macOS:** `bedrock-codex-interval-macos.sh` updates a LaunchAgent using `launchctl`.
- **Linux:** `bedrock-codex-interval` manages a per-user systemd timer using `systemctl --user`.

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

The catalog contains these model IDs and display names:

- `global.openai.gpt-6-astra` — `6 Astra (Global)`
- `global.openai.gpt-6.1-sol` — `6.1 Sol (Global)`
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

### macOS refresh interval

```text
scripts/bedrock-codex-interval-macos.sh
```

Changes the macOS LaunchAgent refresh interval:

```bash
bash ~/.codex/scripts/bedrock-codex-interval-macos.sh 3000
```

`3000` seconds is 50 minutes. Only the script's name has changed; its
LaunchAgent behavior is unchanged. This helper does not work on Linux.

### Linux refresh interval

```text
scripts/bedrock-codex-interval
```

Changes the Linux per-user refresh interval. This separate script is
standalone and can be installed in `~/.local/bin` alongside `bedrock-codex`:

```bash
mkdir -p ~/.local/bin
install -m 755 scripts/bedrock-codex-interval ~/.local/bin/bedrock-codex-interval
```

Run the executable directly; **do not source it** with `source` or `.`.
Installation alone does not turn on the refresh schedule. Run one of the
commands below to start or update it. The command exits after configuring
systemd; you do not need to keep a terminal open or run the script in the
background.

`3000` seconds is 50 minutes. `30` is useful for a short test; restore the
normal interval afterward. These examples use the executable's full path,
so no `PATH` changes or shell sourcing are required. If `~/.local/bin` is on
your `PATH`, you can use `bedrock-codex-interval` as the command name instead.

If you already have a refresh timer, pass its name to update that timer
instead of creating a second schedule. For example, the existing Lambda timer:

```bash
~/.local/bin/bedrock-codex-interval 3000 curatems-bedrock-auth-50m.timer
systemctl --user list-timers curatems-bedrock-auth-50m.timer --all
```

This restarts the named timer with the requested interval. If you do not
already have a refresh timer, create and start the persistent default timer:

```bash
~/.local/bin/bedrock-codex-interval 3000
systemctl --user list-timers codex-bedrock-refresh.timer --all
```

Choose one schedule; do not run both the existing and default timers.
The default command creates, enables, and starts `codex-bedrock-refresh.timer`
and a oneshot service that runs the installed Linux `bedrock-codex --auth`
launcher. Unit files live in `${XDG_CONFIG_HOME:-~/.config}/systemd/user/`.
Later calls change the interval using a timer drop-in without replacing
the service.

Updating an existing timer preserves its service and enablement. A transient
timer remains transient; changing its interval does not make it survive a
reboot. The default timer is enabled for future user-manager sessions.

All Linux operations use `systemctl --user`: no `sudo`, no system-wide units,
and no changes to other Linux accounts. Timers run while your user manager is
running; this script does not enable lingering to keep it running after logout.
The authentication command must already work non-interactively.

To inspect or stop the default Linux timer:

```bash
systemctl --user list-timers codex-bedrock-refresh.timer --all
journalctl --user -u codex-bedrock-refresh.service
systemctl --user disable --now codex-bedrock-refresh.timer
```

## Installation

### macOS

For macOS, copy the scripts into the expected local paths:

```bash
mkdir -p ~/.local/bin ~/.codex/scripts
cp templates/global-gpt6-models.json ~/.codex/global-gpt6-models.json
cp scripts/bedrock-codex ~/.local/bin/
cp scripts/codex-bedrock-creds ~/.local/bin/
cp scripts/bedrock-codex-interval-macos.sh ~/.codex/scripts/
chmod +x ~/.local/bin/bedrock-codex
chmod +x ~/.local/bin/codex-bedrock-creds
chmod +x ~/.codex/scripts/bedrock-codex-interval-macos.sh
```

### Linux / Lambda

Install the standalone Linux interval helper in `~/.local/bin`:

```bash
mkdir -p ~/.local/bin
install -m 755 scripts/bedrock-codex-interval ~/.local/bin/bedrock-codex-interval
```

Then run the helper directly, not with `source`, using one of the startup
commands in [Linux refresh interval](#linux-refresh-interval). Copying or
installing the script does not start a timer by itself.

Keep the host's existing Linux `bedrock-codex` launcher; do not replace it
with this repository's macOS launcher. For Lambda, copy the
same catalog file to the Lambda user's own
`~/.codex/global-gpt6-models.json` and use its absolute path in Lambda's
`config.toml`.

Do not commit AWS credentials, Codex authentication files, `.env` files,
session history, logs, or personal configuration files to this repository.
