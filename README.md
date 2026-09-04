# Monarchic-MCP-client

`@monarchic-ai/monarchic-mcp-client` is a small stdio MCP shim for hosted Monarchic. MCP hosts
start this package locally, and the shim forwards MCP JSON-RPC requests to the
Monarchic-MCP endpoint running in infrastructure.

## Environment test shells

The repository dev shells fetch the tenant-bound infrastructure test API key
from AWS Secrets Manager at shell entry. The key is exported only into the
shell environment and is never evaluated into the Nix store or written to a
local file.

Refresh the repository-managed AWS SSO profiles when needed:

```sh
cd ../monarchic-infra
nix run .#aws-sso-login-all
cd ../monarchic-mcp-client
```

Enter the dev environment, which is also the default shell:

```sh
nix develop .#dev
pnpm smoke:hosted
```

Enter staging explicitly:

```sh
nix develop .#staging
pnpm smoke:hosted
```

The shells set `MONARCHIC_API_BASE_URL`, `MONARCHIC_TENANT_ID`,
`MONARCHIC_MCP_SMOKE_TENANT_ID`, and `MONARCHIC_API_KEY` for the selected
environment. Set `MONARCHIC_AUTO_LOAD_TEST_KEY=0` before entering a shell to
skip the Secrets Manager lookup for offline work or manual credentials.

## Usage

```json
{
  "mcpServers": {
    "monarchic": {
      "command": "pnpm",
      "args": ["dlx", "@monarchic-ai/monarchic-mcp-client"],
      "env": {
        "MONARCHIC_API_BASE_URL": "https://dev-api.monarchic.io",
        "MONARCHIC_BEARER_TOKEN": "<token>"
      }
    }
  }
}
```

You can also set an explicit hosted MCP endpoint:

```sh
export MONARCHIC_MCP_URL=https://dev-api.monarchic.io/mcp/monarchic
export MONARCHIC_BEARER_TOKEN=<token>
pnpm dlx @monarchic-ai/monarchic-mcp-client
```

When working from this repository, `nix develop` and direnv load `.env.local`
when it exists. The published `monarchic-mcp` and `monarchic-mcp-smoke`
commands also load `.env` and `.env.local` from the directory where the command
is started, while preserving already-exported shell variables as highest
priority. Keep local tokens in `.env.local`; the file is ignored by git.

## Configuration

- `MONARCHIC_MCP_URL`: full hosted MCP HTTP endpoint. Takes precedence.
- `MONARCHIC_API_BASE_URL` or `MONARCHIC_API_URL`: base API URL. The shim appends
  `/mcp/monarchic`.
- `MONARCHIC_BEARER_TOKEN` or `MONARCHIC_API_BEARER_TOKEN`: bearer token.
- `MONARCHIC_API_KEY`: API key fallback; sent as `Authorization: Bearer ...`.

The shim does not execute Monarchic locally and does not read cloud resources
directly. All tool behavior belongs to the hosted Monarchic-MCP/API.
The hosted MCP client architecture boundary is documented in
[`docs/hosted-mcp-client-architecture.md`](docs/hosted-mcp-client-architecture.md).

## Hosted Smoke Test

The package includes an opt-in non-interactive smoke command for deployment
checks. It verifies the hosted MCP endpoint, required hosted tools, authenticated
session resolution, and run listing. It can also follow a supplied run id or
launch a new run when explicitly enabled.

```sh
MONARCHIC_API_BASE_URL=https://dev-api.monarchic.io
MONARCHIC_BEARER_TOKEN=<token-or-api-key>
MONARCHIC_MCP_SMOKE_TENANT_ID=dev
```

Then run:

```sh
nix develop -c pnpm smoke:hosted
```

Optional launch/follow inputs:

- `MONARCHIC_MCP_SMOKE_RUN_ID`: follow an existing run after the read-only smoke.
- `MONARCHIC_MCP_SMOKE_LAUNCH=true`: launch a new run, then follow it when the
  launch response includes a run id.
- `MONARCHIC_MCP_SMOKE_PROJECT_KEY`: project key required when launch is enabled.
- `MONARCHIC_MCP_SMOKE_PROMPT`: custom launch prompt.
