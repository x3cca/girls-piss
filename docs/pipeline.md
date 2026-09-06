# Build and deploy pipeline

## Google Drive artwork sync

`tools/sync_drive_assets.py` mirrors raster artwork from the public `Girlspiss`
Drive folder into `assets/art/drive/`. It recursively lists the folder through
[`gdown`](https://github.com/wkentaro/gdown), downloads PNG, JPEG, and WebP
files, trims only fully transparent pixels at the outer edge, and writes
lossless PNGs. Nested Drive folders are retained in the output path.

Set up the optional local Python environment from the repository root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
```

Inspect the folder without downloading or changing project assets:

```sh
python3 tools/sync_drive_assets.py --check
```

Download new or changed files:

```sh
python3 tools/sync_drive_assets.py --sync
```

When an artist adds or replaces Drive artwork, start from the repository root
and run `--check` first. Review the reported names and counts, then run
`--sync`; this is the canonical way for a new agent to pull the latest assets.
The command writes only processed files to `assets/art/drive/`: transparent
outer borders are trimmed, the original crop is preserved, and files without a
Drive extension are saved as `.png`. Review the resulting dimensions and the
scene references before committing. Do not copy files from the ignored cache or
commit the raw downloads. If a source file disappears, the tool reports it but
keeps the existing local output so a remote cleanup cannot silently break a
scene.

The default source is
`REDACTED`.
Use `--source URL` or set `DRIVE_ASSETS_URL` when the folder changes.
`--output` and `--cache-dir` are also available for local experiments and
tests.

The ignored `.cache/drive-assets/` directory contains the source manifest and
temporary raw downloads. The manifest uses Drive file IDs plus listing and
HTTP metadata (when available) to recognize unchanged files. Drive files
removed from the source are reported but their local PNGs are never deleted.

Unsupported files are listed as skipped and do not fail the run. A failed
download, image decode, output write, or manifest write prints an error and
returns status 1; successful files from the same run remain usable. Output
PNGs and the manifest are replaced atomically, so an interrupted write cannot
leave a partial destination file.

Offline tests for cropping, format conversion, manifest change detection, path
collisions, idempotence, removal reporting, and failures can be run with:

```sh
python3 -m unittest tests.test_sync_drive_assets
```

## Checks and tests

`gdchecks.yml` runs the Godot headless project check and a separate `GUT unit
tests` job on every pull request and push to `main`/`master`. The test job
executes `./tools/run-tests.sh` in the same Godot CI container used by the
project checks and uploads the JUnit report as `godot-test-results`, including
when tests fail.

build-and-deploy.yml follows the current Date-or-Mate-2 workflow:

1. Run in barichello/godot-ci:4.7.2.
2. Import the project headlessly.
3. Export the Web preset to build/web/index.html.
4. Upload the build as a GitHub Actions artifact.
5. Push the build to itch.io with Butler.

The workflow targets the html-staging channel. The html prefix makes the
channel browser-playable on itch.io. The Web PCK is checked against a 12 MB cap;
the limit leaves room for the authored Level 1 and game-over artwork while still
catching an accidental export of the full development asset tree.

## GitHub Actions secrets

Set these under Repository → Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| BUTLER_API_KEY | itch.io API key from Account → Developer → API Keys |
| ITCH_USERNAME | itch.io account name |

The current page is https://cooldotty.itch.io/girls-piss, and the deployment
workflow targets the `girls-piss` slug directly.

The kc9y... secret URL token is not a Butler API key. Keep it out of GitHub
Actions unless a separate workflow explicitly needs it.

## Export notes

The Web preset exports the main scene and its dependencies instead of every
project resource. Runtime-loaded scripts, trace/feedback scenes, target art,
volume controls, and the cursor are explicitly included because Godot's scenes
filter cannot discover every preload used by the generated Level 1 script. The
nine prompt icons used by `InputPrompt` are also explicitly included so they
remain available at runtime while the rest of the Kenney pack stays out of the
PCK. The MCP and GUT addons, tests, and development scripts are excluded in
`export_presets.cfg`; the MCP plugin also skips its editor-only runtime autoload
while an export command is running. CI checks the resulting PCK stays below 12
MB and contains Level 1's critical runtime resources without test or MCP files.
