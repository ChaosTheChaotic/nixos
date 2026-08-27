{
  description = "Tree-sitter - A parser generator tool and an incremental parsing library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    tree-sitter-src = {
      url = "github:tree-sitter/tree-sitter";
      flake = false;
    };

    grammar-bash = {
      url = "github:tree-sitter/tree-sitter-bash";
      flake = false;
    };
    grammar-c = {
      url = "github:tree-sitter/tree-sitter-c";
      flake = false;
    };
    grammar-cpp = {
      url = "github:tree-sitter/tree-sitter-cpp";
      flake = false;
    };
    grammar-embedded-template = {
      url = "github:tree-sitter/tree-sitter-embedded-template";
      flake = false;
    };
    grammar-go = {
      url = "github:tree-sitter/tree-sitter-go";
      flake = false;
    };
    grammar-html = {
      url = "github:tree-sitter/tree-sitter-html";
      flake = false;
    };
    grammar-java = {
      url = "github:tree-sitter/tree-sitter-java";
      flake = false;
    };
    grammar-javascript = {
      url = "github:tree-sitter/tree-sitter-javascript";
      flake = false;
    };
    grammar-jsdoc = {
      url = "github:tree-sitter/tree-sitter-jsdoc";
      flake = false;
    };
    grammar-json = {
      url = "github:tree-sitter/tree-sitter-json";
      flake = false;
    };
    grammar-php = {
      url = "github:tree-sitter/tree-sitter-php";
      flake = false;
    };
    grammar-python = {
      url = "github:tree-sitter/tree-sitter-python";
      flake = false;
    };
    grammar-ruby = {
      url = "github:tree-sitter/tree-sitter-ruby";
      flake = false;
    };
    grammar-rust = {
      url = "github:tree-sitter/tree-sitter-rust";
      flake = false;
    };
    grammar-typescript = {
      url = "github:tree-sitter/tree-sitter-typescript";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (inputs) self;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      eachSystem = lib.genAttrs systems;
      pkgsFor = inputs.nixpkgs.legacyPackages;

      version = "0.27.0";

      # Use the source input directly
      src = inputs.tree-sitter-src;

      # Map the grammar inputs dynamically
      testGrammars = {
        bash = inputs.grammar-bash;
        c = inputs.grammar-c;
        cpp = inputs.grammar-cpp;
        embedded-template = inputs.grammar-embedded-template;
        go = inputs.grammar-go;
        html = inputs.grammar-html;
        java = inputs.grammar-java;
        javascript = inputs.grammar-javascript;
        jsdoc = inputs.grammar-jsdoc;
        json = inputs.grammar-json;
        php = inputs.grammar-php;
        python = inputs.grammar-python;
        ruby = inputs.grammar-ruby;
        rust = inputs.grammar-rust;
        typescript = inputs.grammar-typescript;
      };
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          crossTargets = {
            aarch64-linux = pkgs.pkgsCross.aarch64-multiplatform;
            armv7l-linux = pkgs.pkgsCross.armv7l-hf-multiplatform;
            x86_64-linux = pkgs.pkgsCross.gnu64;
            i686-linux = pkgs.pkgsCross.gnu32;
            loongarch64 = pkgs.pkgsCross.loongarch64-linux;
            mips = pkgs.pkgsCross.mips-linux-gnu;
            mips64 = pkgs.pkgsCross.mips64-linux-gnuabi64;
            musl64 = pkgs.pkgsCross.musl64;
            powerpc64-linux = pkgs.pkgsCross.ppc64;
            riscv32 = pkgs.pkgsCross.riscv32;
            riscv64 = pkgs.pkgsCross.riscv64;
            s390x = pkgs.pkgsCross.s390x;

            x86_64-windows = pkgs.pkgsCross.mingwW64;
          }
          // (lib.optionalAttrs pkgs.stdenv.isDarwin {
            x86_64-darwin = pkgs.pkgsCross.x86_64-darwin;
            aarch64-darwin = pkgs.pkgsCross.aarch64-darwin;
          });

        in
        {
          default = self.packages.${system}.cli;

          docs = pkgs.callPackage ./docs/package.nix { inherit src version; };

          test-grammars = pkgs.stdenv.mkDerivation {
            inherit src version;

            pname = "test-grammars";

            buildPhase = ''
              mkdir -p test/fixtures/grammars
              ${lib.concatMapStrings (name: ''
                cp -r ${testGrammars.${name}} test/fixtures/grammars/${name}
              '') (lib.attrNames testGrammars)}
            '';

            installPhase = ''
              mkdir -p $out
              cp -r test/fixtures $out/fixtures
            '';
          };

          wasm-test-grammars = pkgs.callPackage ./lib/binding_web/wasm-test-grammars.nix {
            inherit src version;
            inherit (self.packages.${system}) cli test-grammars;
          };

          web-tree-sitter = pkgs.callPackage ./lib/binding_web/package.nix {
            inherit src version;
            inherit (self.packages.${system}) wasm-test-grammars;
          };

          lib = pkgs.callPackage ./lib/package.nix {
            inherit src version;
          };

          cli = pkgs.callPackage ./crates/cli/package.nix {
            inherit src version;
            inherit (self.packages.${system}) test-grammars;
          };
        }
        // (lib.mapAttrs' (arch: pkg: {
          name = "cli-${arch}";
          value = pkg.callPackage ./crates/cli/package.nix {
            inherit src version;
            inherit (self.packages.${system}) test-grammars;
          };
        }) crossTargets)
        // (lib.mapAttrs' (arch: pkg: {
          name = "lib-${arch}";
          value = pkg.callPackage ./lib/package.nix {
            inherit src version;
          };
        }) crossTargets)
      );

      apps = eachSystem (system: {
        default = self.apps.${system}.cli;

        cli = {
          type = "app";
          program = "${lib.getExe self.packages.${system}.cli}";
          meta.description = "Tree-sitter CLI for developing, testing, and using parsers";
        };
      });
    };
}
