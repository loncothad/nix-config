{
  buildNpmPackage,
  fetchurl,
  lib,
}:

buildNpmPackage (finalAttrs: {
  pname = "zcode-coding-helper";
  version = "0.1.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@z_ai/coding-helper/-/coding-helper-${finalAttrs.version}.tgz";
    hash = "sha512-oMYZBiyqns0SKLz8IhZFNg6GF+fgoohHleOAg0/JxEj/6Wlo9BIAZAhS711W0c82HvQVk8OuK1QIRKi9YipHbQ==";
  };

  postPatch = ''
    cp ${./coding-helper/package.json} package.json
    cp ${./coding-helper/package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-2fIGrNJoBH/PNizoBmEwViuL5yhOZL4ocG40Z5Tez3Q=";
  dontNpmBuild = true;

  meta = {
    description = "Official Z.AI terminal helper for managing coding tools";
    homepage = "https://docs.z.ai/devpack/extension/coding-tool-helper";
    license = lib.licenses.unfree;
    mainProgram = "coding-helper";
    platforms = lib.platforms.all;
  };
})
