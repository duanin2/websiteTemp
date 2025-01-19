{
  description = "Cobalt site generation";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;
  in {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        cobalt
        (let
          remote = "RPi5:/persist/www/duanin2.top";
          mountPath = "/tmp/cobalt-upload";
        in writeShellScriptBin "upload" ''
echo "Cleaning old generated site..."
${lib.getExe cobalt} clean --quiet

echo "Building new site..."
${lib.getExe cobalt} build --no-drafts --quiet

echo "Mounting SSHFS..."
mkdir ${mountPath}
${lib.getExe sshfs} ${remote} ${mountPath}

echo "Copying site..."
rm -r ${mountPath}/*
cp -r ./_site/* ${mountPath}

echo "Unmounting SSHFS..."
umount ${mountPath}
rm -rf ${mountPath}

echo "Cleaning new generated site..."
${lib.getExe cobalt} clean --quiet
        '')
      ];
    };
  });
}