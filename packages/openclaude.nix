{ lib
, buildNpmPackage
, fetchzip
, nodejs_22
, ripgrep
,
}:

buildNpmPackage (finalAttrs: {
  pname = "openclaude";
  version = "0.24.0";

  # fetchzip strips the leading `package/` directory that npm tarballs use.
  src = fetchzip {
    url = "https://registry.npmjs.org/@gitlawb/openclaude/-/openclaude-${finalAttrs.version}.tgz";
    hash = "sha256-DwBe61WBKvb3RYg/MQcWEAMULyIG/u82OPOVNCX1xe4=";
  };

  # npm tarballs don't include package-lock.json; we vendor one alongside this file.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-8bi6Qa3BLYcjrXiL2OG+QkntomsUe6Rwu24sPkvm3Qk=";

  nodejs = nodejs_22;
  dontNpmBuild = true; # dist/cli.mjs is pre-built in the tarball (Bun output)

  # @vscode/ripgrep postinstall downloads a ripgrep binary from GitHub at
  # install time, which fails in the Nix sandbox. Skip all postinstall scripts
  # and instead inject the system ripgrep via wrapProgram.
  npmFlags = "--ignore-scripts";

  postInstall = ''
    wrapProgram $out/bin/openclaude \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Agentic coding assistant CLI supporting multiple LLM providers";
    homepage = "https://github.com/Gitlawb/openclaude";
    downloadPage = "https://www.npmjs.com/package/@gitlawb/openclaude";
    license = lib.licenses.mit;
    mainProgram = "openclaude";
    platforms = lib.platforms.unix;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
  };
})
