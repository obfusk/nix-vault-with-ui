{ pkgs ? import <nixpkgs> {} }:

let
  buildNpmPackage = pkgs.callPackage ~/dev/nix-npm-buildpackage {};
  integreties = {
   "https://codeload.github.com/icholy/Duration.js/tar.gz/cb1c58efc2772ef0f261da9e2535890734a86417"         = "sha512-WZEMW8xDHHnxu2RK9y8YzSXgzOLveGPwRWEHSGYcEsLts52MN3M7lZaPLyZoHW8FOpVbM+2H5wnhOR+6RJZJIw==";
   "https://codeload.github.com/meirish/broccoli-sri-hash/tar.gz/5ebad6f345c38d45461676c7a298a0b61be4a39d"  = "sha512-G3Rs6Xbn8UXNJznKcEUn9kA6CTvyU2xdmZkEUJniSO9mLmBuMmBEhLJXIblYiOPjcO8l5YuiKDq/r49R6IvStA==";
   "https://codeload.github.com/meirish/ember-cli-sri/tar.gz/1c0ff776a61f09121d1ea69ce16e4653da5e1efa"      = "sha512-Rm87BsYdlZBYt/SdYq/ADmBpR7PsxIi1seuxaCsFuLIkr8c5ME7fdi9aRfwUFvbFMQStRu12BDfl9hs92EPY1A==";
  };

# yarnOpts = "--offline --cache-folder ./npm-cache/_cacache";

  vault-ui = src: buildNpmPackage {
    inherit src;
    useYarnLock     = true;
    yarnIntegreties = integreties;
    npmBuildMore    = ''
     # npm ls
     # exit 1
     npm rebuild node-sass
     npm run build-dev
    '';
  # npmBuildMore    = "yarn ${yarnOpts} && npm rebuild node-sass && yarn ${yarnOpts} run build-dev";
  # buildInputs     = [ pkgs.yarn ];
    buildInputs     = [ pkgs.git ];
  };

  vault = pkgs.callPackage vault' {};

  vault' = { stdenv, fetchFromGitHub, go, gox, removeReferencesTo }:

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

    nativeBuildInputs = [ go gox removeReferencesTo ];

    preBuild = ''
      patchShebangs ./
      substituteInPlace scripts/build.sh --replace 'git rev-parse HEAD' 'echo ${src.rev}'
      sed -i s/'^GIT_DIRTY=.*'/'GIT_DIRTY="+NixOS"'/ scripts/build.sh

      mkdir -p .git/hooks src/github.com/hashicorp
      ln -s $(pwd) src/github.com/hashicorp/vault

      export GOPATH=$(pwd)

      rm -fr ui/ && ln -s ${vault-ui (src+"/ui")} ui";
    '';

    buildPhase = "make static-assets dev-ui";

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
