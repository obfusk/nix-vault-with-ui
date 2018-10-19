{ pkgs ? import <nixpkgs> {} }:

let
  bp = pkgs.callPackage ~/dev/nix-npm-buildpackage {};

  integreties = {
   "https://codeload.github.com/icholy/Duration.js/tar.gz/cb1c58efc2772ef0f261da9e2535890734a86417"         = "sha512-WZEMW8xDHHnxu2RK9y8YzSXgzOLveGPwRWEHSGYcEsLts52MN3M7lZaPLyZoHW8FOpVbM+2H5wnhOR+6RJZJIw==";
   "https://codeload.github.com/meirish/broccoli-sri-hash/tar.gz/5ebad6f345c38d45461676c7a298a0b61be4a39d"  = "sha512-G3Rs6Xbn8UXNJznKcEUn9kA6CTvyU2xdmZkEUJniSO9mLmBuMmBEhLJXIblYiOPjcO8l5YuiKDq/r49R6IvStA==";
   "https://codeload.github.com/meirish/ember-cli-sri/tar.gz/1c0ff776a61f09121d1ea69ce16e4653da5e1efa"      = "sha512-Rm87BsYdlZBYt/SdYq/ADmBpR7PsxIi1seuxaCsFuLIkr8c5ME7fdi9aRfwUFvbFMQStRu12BDfl9hs92EPY1A==";
  };

  node-sass-path = "node_modules/node-sass/vendor/linux-x64-64/binding.node";
  node-sass = pkgs.fetchurl {
    url     = "https://github.com/sass/node-sass/releases/download/v4.9.3/linux-x64-64_binding.node";
    sha512  = "53b91bf2ea906b24834da9650b44db2fb3cd347ee6713a709f8f95fe996deaf4121c508c0e5d37be8601b667e763d4b804429735a43fdab8898f15dd383563ae";
  };

  vault-ui = src: bp.buildYarnPackage {
    inherit src integreties;

    # replaces `make ember-dist`
    yarnBuildMore = ''
      # replaces `npm rebuild node-sass`
      mkdir -p `dirname ${node-sass-path}`
      ln -s ${node-sass} ${node-sass-path}

      # thanks ember
      mkdir _HOME
      HOME=$PWD/_HOME yarn run build
      rm -fr _HOME

      # let's not keep that in the parent dir
      mv ../pkg/web_ui _web_ui
    '';
  };

  vault = pkgs.callPackage vault' {};

  vault' = { stdenv, fetchFromGitHub, go, gox, go-bindata,
             go-bindata-assetfs, removeReferencesTo }:

  let
    # Deprecated since vault 0.8.2: use `vault -autocomplete-install` instead
    # to install auto-complete for bash, zsh and fish
    vaultBashCompletions = fetchFromGitHub {
      owner = "iljaweis";
      repo = "vault-bash-completion";
      rev = "e2f59b64be1fa5430fa05c91b6274284de4ea77c";
      sha256 = "10m75rp3hy71wlmnd88grmpjhqy0pwb9m8wm19l0f463xla54frd";
    };
  in stdenv.mkDerivation rec {
    name = "vault-${version}";
    version = "0.11.2";

    src = fetchFromGitHub {
      owner = "hashicorp";
      repo = "vault";
      rev = "v${version}";
      sha256 = "0lckpfp1yw6rfq2cardsp2qjiajg706qjk98cycrlsa5nr2csafa";
    };

    buildUI = true;

    nativeBuildInputs = [ go gox removeReferencesTo ] ++
                        stdenv.lib.optionals buildUI
                        [ go-bindata go-bindata-assetfs ];

    preBuild = ''
      patchShebangs ./
      substituteInPlace scripts/build.sh --replace 'git rev-parse HEAD' 'echo ${src.rev}'
      sed -i s/'^GIT_DIRTY=.*'/'GIT_DIRTY="+NixOS"'/ scripts/build.sh

      mkdir -p .git/hooks src/github.com/hashicorp
      ln -s $(pwd) src/github.com/hashicorp/vault

      export GOPATH=$(pwd)
    '' + (if buildUI then ''
      rm -fr ui
      ln -s ${vault-ui (src + "/ui")} ui

      # link the web_ui we moved in yarnBuildMore
      mkdir -p pkg
      ln -s ../ui/_web_ui pkg/web_ui
    '' else "");

    makeFlags = if buildUI then "static-assets dev-ui" else "";

    installPhase = ''
      mkdir -p $out/bin $out/share/bash-completion/completions

      cp pkg/*/* $out/bin/
      find $out/bin -type f -exec remove-references-to -t ${go} '{}' +

      cp ${vaultBashCompletions}/vault-bash-completion.sh $out/share/bash-completion/completions/vault
    '';

    meta = with stdenv.lib; {
      homepage = https://www.vaultproject.io;
      description = "A tool for managing secrets";
      platforms = platforms.linux ++ platforms.darwin;
      license = licenses.mpl20;
      maintainers = with maintainers; [ rushmorem lnl7 offline pradeepchhetri ];
    };
  };
in { inherit vault; }
