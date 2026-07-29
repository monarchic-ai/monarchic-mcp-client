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
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_22
              pkgs.pnpm
            ];
            shellHook = ''
              if [ -f .env.local ]; then
                set -a
                . ./.env.local
                set +a
              fi
            '';
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
