{
  description = "Cobalt site generation";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;
  in {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; let
        inkscapeExport = extraParams: inputFile: outputFile: "${lib.getExe inkscape} -o \"${outputFile}\" ${extraParams} \"${inputFile}\"";

        generate = let
          imagesLocation = "./images";

          generateIconPNG = width: inkscapeExport "-C -w ${toString width} -h ${toString width}" "./data/favicon-source.svg" "${imagesLocation}/icon-${toString width}px.png";
        in writeShellScriptBin "generate" ''
echo "Cleaning images..."
rm -rf ${imagesLocation}/*

echo "Generating images..."
${inkscapeExport "-C" "./data/favicon-source.svg" "${imagesLocation}/icon.svg"}
${generateIconPNG 180}
${generateIconPNG 167}
${generateIconPNG 152}
${generateIconPNG 120}

cp ./data/valid-rss-rogers.png ${imagesLocation}/validrss-badge.png
cp ./data/vcss.png ${imagesLocation}/validcss-badge.png
${inkscapeExport "-C -h 31" "./data/ai-label_banner-no-ai-used.svg" "${imagesLocation}/no-ai-badge.png"}

echo "Cleaning styles..."
rm -rf ./styles/*

echo "Generating styles..."
cp ./data/style.css ./styles/style.css
${lib.getExe stripCSS} ./styles/catppuccin.css ./data/catppuccin.css ./styles/style.css
        '';
        stripCSS = writeScriptBin "strip-css" ''
#!${lib.getExe nushell}

def main [
  outputFile: string
  variablesFile: string
  filterFile: string
] {
  let variables = open $variablesFile | lines | where { |line| $line starts-with "  --" } | split column : | par-each { |line| { name: ($line.column1 | str trim) value: ($line.column2 | str trim | str replace ";" "") } };
  let filter = open $filterFile;

  let variables = $variables | where { |variable| $filter | str contains $variable.name }
  $":root {($variables | par-each { |variable| $variable.name + : + $variable.value } | str join ';')}" | save $outputFile
}
        '';

        upload = (let
          remote = "RPi5:/persist/www/duanin2.top";
          mountPath = "/tmp/cobalt-upload";
        in writeShellScriptBin "upload" ''
${lib.getExe generate}

echo "Mounting SSHFS..."
mkdir ${mountPath}
${lib.getExe sshfs} ${remote} ${mountPath}

echo "Cleaning remote folder..."
rm -rf ${mountPath}/*

echo "Building new site..."
${lib.getExe cobalt} build --no-drafts --quiet -d ${mountPath}

echo "Unmounting SSHFS..."
umount ${mountPath}
rm -rf ${mountPath}
        '');
        serve = writeShellScriptBin "serve" ''
${lib.getExe generate}

${lib.getExe cobalt} serve --drafts
        '';
      in [
        cobalt

        generate
        stripCSS

        upload
        serve
      ];
    };
  });
}