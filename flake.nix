{
  description = "Monarchic-MCP-client hosted MCP client shim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          packageJson = builtins.fromJSON (builtins.readFile ./package.json);
          pname = "monarchic-mcp-client";
          version = packageJson.version;
          pnpmDeps = pkgs.fetchPnpmDeps {
            inherit pname version;
            src = ./.;
            pnpm = pkgs.pnpm_10;
            fetcherVersion = 3;
            hash = "sha256-3YC7VMjYegGJJ18dTNGOo6NmHJ1IjUjYmwHXBzWFoB8=";
          };
          client = pkgs.stdenv.mkDerivation {
            inherit pname version pnpmDeps;
            src = ./.;

            nativeBuildInputs = with pkgs; [
              nodejs_24
              pnpm_10
              pnpmConfigHook
              makeWrapper
            ];

            buildPhase = ''
              runHook preBuild
              pnpm run build
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/libexec/${pname}" "$out/bin"
              cp -R dist node_modules package.json pnpm-lock.yaml README.md LICENSE "$out/libexec/${pname}/"

              makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/monarchic-mcp" \
                --add-flags "$out/libexec/${pname}/dist/bin/monarchic-mcp.js"
              makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/monarchic-mcp-smoke" \
                --add-flags "$out/libexec/${pname}/dist/bin/hosted-mcp-smoke.js"

              runHook postInstall
            '';

            meta = {
              description = "Hosted Monarchic-MCP stdio client shim.";
              homepage = "https://github.com/monarchic-ai/Monarchic-MCP-client";
              license = pkgs.lib.licenses.mit;
              mainProgram = "monarchic-mcp";
            };
          };
        in
        {
          monarchic-mcp-client = client;
          default = client;
        }
      );

      apps = forAllSystems (system: {
        "monarchic-mcp" = {
          type = "app";
          program = "${self.packages.${system}.monarchic-mcp-client}/bin/monarchic-mcp";
        };
        "monarchic-mcp-smoke" = {
          type = "app";
          program = "${self.packages.${system}.monarchic-mcp-client}/bin/monarchic-mcp-smoke";
        };
        default = self.apps.${system}.monarchic-mcp;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkClientShell =
            {
              environment,
              awsProfile,
              apiBaseUrl,
              tenantId,
              apiKeySecret,
            }:
            pkgs.mkShell {
              packages = [
                pkgs.awscli2
                pkgs.nodejs_22
                pkgs.pnpm
              ];
              shellHook = ''
                if [ -f .env.local ]; then
                  set -a
                  . ./.env.local
                  set +a
                fi

                export MONARCHIC_ENV="${environment}"
                export AWS_PROFILE="${awsProfile}"
                export AWS_REGION="us-east-2"
                export MONARCHIC_API_BASE_URL="${apiBaseUrl}"
                export MONARCHIC_TENANT_ID="${tenantId}"
                export MONARCHIC_MCP_SMOKE_TENANT_ID="${tenantId}"

                if [ "''${MONARCHIC_AUTO_LOAD_TEST_KEY:-1}" != "0" ]; then
                  unset MONARCHIC_BEARER_TOKEN MONARCHIC_API_BEARER_TOKEN MONARCHIC_API_KEY
                  monarchic_aws_config="''${AWS_CONFIG_FILE:-''${XDG_CACHE_HOME:-$HOME/.cache}/monarchic/aws-sso/config}"
                  export AWS_CONFIG_FILE="$monarchic_aws_config"

                  if monarchic_test_key="$(
                    AWS_MAX_ATTEMPTS=2 AWS_RETRY_MODE=standard aws secretsmanager get-secret-value \
                      --profile "${awsProfile}" \
                      --region us-east-2 \
                      --cli-connect-timeout 5 \
                      --cli-read-timeout 10 \
                      --secret-id "${apiKeySecret}" \
                      --query SecretString \
                      --output text \
                      2>/dev/null
                  )" && [ -n "$monarchic_test_key" ]; then
                    export MONARCHIC_API_KEY="$monarchic_test_key"
                    printf 'Loaded the %s Monarchic infrastructure test key from AWS Secrets Manager.\n' "${environment}"
                  else
                    printf 'Monarchic %s test key was not loaded. Refresh AWS SSO in ../monarchic-infra and re-enter this shell.\n' "${environment}" >&2
                  fi

                  unset monarchic_test_key monarchic_aws_config
                fi
              '';
            };
          devShell = mkClientShell {
            environment = "dev";
            awsProfile = "monarchic-dev";
            apiBaseUrl = "https://dev-api.monarchic.io";
            tenantId = "dev";
            apiKeySecret = "monarchic-dev/infrastructure-test-api-key";
          };
        in
        rec {
          default = devShell;
          dev = devShell;
          staging = mkClientShell {
            environment = "staging";
            awsProfile = "monarchic-staging";
            apiBaseUrl = "https://staging-api.monarchic.io";
            tenantId = "tenant-monarchic-staging-internal";
            apiKeySecret = "monarchic-staging/infrastructure-test-api-key";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          packageJson = builtins.fromJSON (builtins.readFile ./package.json);
          pname = "monarchic-mcp-client";
          version = packageJson.version;
        in
        {
          package = self.packages.${system}.monarchic-mcp-client;
          tests = pkgs.stdenv.mkDerivation {
            inherit pname version;
            src = ./.;
            pnpmDeps = pkgs.fetchPnpmDeps {
              inherit pname version;
              src = ./.;
              pnpm = pkgs.pnpm_10;
              fetcherVersion = 3;
              hash = "sha256-3YC7VMjYegGJJ18dTNGOo6NmHJ1IjUjYmwHXBzWFoB8=";
            };
            nativeBuildInputs = with pkgs; [
              nodejs_24
              pnpm_10
              pnpmConfigHook
            ];
            buildPhase = ''
              runHook preBuild
              pnpm run test
              runHook postBuild
            '';
            installPhase = ''
              touch "$out"
            '';
          };
        }
      );
    };
}
