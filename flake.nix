{
  description = "Permstrap";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    inputs:
    let
      system = "aarch64-darwin";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;

      meson = pkgs.meson.overridePythonAttrs (_: {
        version = "1.11.2";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/source/m/meson/meson-1.11.2.tar.gz";
          hash = "sha256-aY/q4GnO8+zU16rygdffNZvfz1VamhVkOD07kT+opzY=";
        };

        # Permstrap's full Meson suite exercises this pinned build. Avoid making
        # every downstream user rerun Meson's much larger upstream test matrix.
        doCheck = false;
        doInstallCheck = false;
        nativeCheckInputs = [ ];
        checkInputs = [ ];
      });
      yyjsonArchive = pkgs.fetchurl {
        url = "https://github.com/ibireme/yyjson/archive/refs/tags/0.12.0.tar.gz";
        hash = "sha256-sWJG9heyoTbHjXPl4mR8bx3hMT5GZ4BimFvc8fQLt10=";
      };
      argtable3Archive = pkgs.fetchurl {
        url = "https://github.com/argtable/argtable3/releases/download/v3.3.1/argtable-v3.3.1-amalgamation.tar.gz";
        hash = "sha256-AOsEG+3YSn4ZEuX4qV2ECDUIdNyntG1u0RC/rEQ0JmM=";
      };
      ccArchive = pkgs.fetchurl {
        url = "https://github.com/JacksonAllan/CC/archive/refs/tags/v1.4.3.tar.gz";
        hash = "sha256-iOzGeyZQiRcH02SlS/OYSSckBTCizespZBVIXcFLOFk=";
      };
      libsodiumArchive = pkgs.fetchurl {
        url = "https://github.com/jedisct1/libsodium/releases/download/1.0.22-RELEASE/libsodium-1.0.22.tar.gz";
        hash = "sha256-rb3Y8WFJ6BrGB4oDrKb8A7WSuJ73te2DhBwIYZG+M0k=";
      };
      utf8procArchive = pkgs.fetchurl {
        url = "https://github.com/JuliaStrings/utf8proc/releases/download/v2.11.3/utf8proc-2.11.3.tar.gz";
        hash = "sha256-QVGJ/SyFzW7l/yavUA+jh96a2h4+MW6T9zOFUUgdVX0=";
      };

      nativeTools =
        with pkgs;
        [
          actool
          clang-tools
          makeWrapper
          ninja
          shellcheck
          shfmt
        ]
        ++ [ meson ];

      permstrap = pkgs.stdenv.mkDerivation {
        pname = "permstrap";
        version = "1.0.0";

        __structuredAttrs = true;
        strictDeps = true;

        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./developer
            (lib.fileset.maybeMissing ./examples)
            ./resources
            ./src
            ./subprojects/.wraplock
            ./subprojects/argtable3.wrap
            ./subprojects/cc.wrap
            ./subprojects/libsodium.wrap
            ./subprojects/utf8proc.wrap
            ./subprojects/yyjson.wrap
            ./subprojects/packagefiles
            ./tests
            ./README.md
            ./.clang-format
            ./meson.build
            ./meson.options
          ];
        };

        postPatch = ''
          mkdir -p subprojects/packagecache
          cp ${argtable3Archive} \
            subprojects/packagecache/argtable-v3.3.1-amalgamation.tar.gz
          cp ${ccArchive} subprojects/packagecache/cc-1.4.3.tar.gz
          cp ${libsodiumArchive} subprojects/packagecache/libsodium-1.0.22.tar.gz
          cp ${utf8procArchive} subprojects/packagecache/utf8proc-2.11.3.tar.gz
          cp ${yyjsonArchive} subprojects/packagecache/yyjson-0.12.0.tar.gz
        '';

        nativeBuildInputs = nativeTools;
        buildInputs = [ pkgs.apple-sdk_26 ];

        env = {
          # The Nix Clang wrapper adds link search paths even to --analyze.
          NIX_CFLAGS_COMPILE = "-Wno-error=unused-command-line-argument";
        };

        mesonFlags = [ "-Ddeveloper_checks=enabled" ];

        doCheck = true;

        postInstall = ''
          makeWrapper \
            "$out/Applications/Permstrap.app/Contents/MacOS/permstrap" \
            "$out/bin/permstrap"
        '';

        # The application bundle is signed during its Meson build.
        dontStrip = true;

        meta = {
          description = "Native macOS permissions workflow and permission probe";
          homepage = "https://github.com/4evy/permstrap";
          mainProgram = "permstrap";
          platforms = [ system ];
        };
      };
    in
    {
      packages.${system} = {
        default = permstrap;
        inherit permstrap;
      };

      checks.${system}.permstrap = permstrap;

      apps.${system}.default = {
        type = "app";
        program = lib.getExe permstrap;
        meta.description = permstrap.meta.description;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = nativeTools ++ [ pkgs.just ];
        buildInputs = [ pkgs.apple-sdk_26 ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
