{ pkgs ? import <nixpkgs> {} }:

let
  # TODO: fetchGit
  bp = pkgs.callPackage ~/dev/nix-npm-buildpackage {};

  integreties = {
   "https://codeload.github.com/icholy/Duration.js/tar.gz/cb1c58efc2772ef0f261da9e2535890734a86417"         = "sha512-WZEMW8xDHHnxu2RK9y8YzSXgzOLveGPwRWEHSGYcEsLts52MN3M7lZaPLyZoHW8FOpVbM+2H5wnhOR+6RJZJIw==";
   "https://codeload.github.com/meirish/broccoli-sri-hash/tar.gz/5ebad6f345c38d45461676c7a298a0b61be4a39d"  = "sha512-G3Rs6Xbn8UXNJznKcEUn9kA6CTvyU2xdmZkEUJniSO9mLmBuMmBEhLJXIblYiOPjcO8l5YuiKDq/r49R6IvStA==";
   "https://codeload.github.com/meirish/ember-cli-sri/tar.gz/1c0ff776a61f09121d1ea69ce16e4653da5e1efa"      = "sha512-Rm87BsYdlZBYt/SdYq/ADmBpR7PsxIi1seuxaCsFuLIkr8c5ME7fdi9aRfwUFvbFMQStRu12BDfl9hs92EPY1A==";
  };

  vault-ui = src: bp.buildYarnPackage {
    inherit src integreties;

    # replaces `make ember-dist`
    yarnBuildMore = ''
      # thanks ember
      mkdir _HOME
      HOME=$PWD/_HOME yarn run build
      rm -fr _HOME

      # let's not keep that in the parent dir
      mv ../pkg/web_ui _web_ui
    '';

    buildInputs = with pkgs; [ phantomjs2 python2 ];
  };

  vault = pkgs.callPackage vault' {};

  vault' = { go-bindata, go-bindata-assetfs, buildUI ? true }:
    let
      old = pkgs.vault;
    in old // rec {
      inherit buildUI;

      nativeBuildInputs = old.nativeBuildInputs ++
        pkgs.lib.optionals buildUI [ go-bindata go-bindata-assetfs ];

      preBuild = old.preBuild + (if buildUI then ''
        rm -fr ui
        ln -s ${vault-ui (old.src + "/ui")} ui

        # link the web_ui we moved in yarnBuildMore
        mkdir -p pkg
        ln -s ../ui/_web_ui pkg/web_ui

        # eh...
        substituteInPlace Makefile --replace '-o bindata_assetfs.go' ""
      '' else "");

      makeFlags = if buildUI then "static-assets dev-ui" else "";
    };
in { inherit vault; }
