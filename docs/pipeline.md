# Build and deploy pipeline

build-and-deploy.yml follows the current Date-or-Mate-2 workflow:

1. Run in barichello/godot-ci:4.7.2.
2. Import the project headlessly.
3. Export the Web preset to build/web/index.html.
4. Upload the build as a GitHub Actions artifact.
5. Push the build to itch.io with Butler.

The workflow targets the html-staging channel. The html prefix makes the
channel browser-playable on itch.io.

## GitHub Actions secrets

Set these under Repository → Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| BUTLER_API_KEY | itch.io API key from Account → Developer → API Keys |
| ITCH_USERNAME | itch.io account name |
| ITCH_GAME | itch.io game slug |

The current page is https://cooldotty.itch.io/girl-pisser, so the latter two
values are cooldotty and girl-pisser.

The kc9y... secret URL token is not a Butler API key. Keep it out of GitHub
Actions unless a separate workflow explicitly needs it.

## Export notes

The MCP addon is excluded in export_presets.cfg. Keep editor-only plugins out
of runtime builds unless the game specifically needs them.
