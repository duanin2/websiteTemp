{
  description = "Cobalt site generation";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;
  in {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; let
        inkscapeExport = extraParams: inputFile: outputFile: "${lib.getExe inkscape} -o \"${outputFile}\" ${extraParams} \"${inputFile}\"";

        generate = let
          imagesLocation = "./images";

          generateIconPNG = colorScheme: width: inkscapeExport "-C -w ${toString width} -h ${toString width}" "${imagesLocation}/icons/${colorScheme}/any.svg" "${imagesLocation}/icons/${colorScheme}/${toString width}.png";

          generateIconsColorScheme = colorScheme: ''
${lib.getExe patternReplace} $TmpDir/template.svg ${imagesLocation}/icons/${colorScheme}/any.svg ./data/replacePatterns/icon-svg/${colorScheme}.csv
${generateIconPNG "${colorScheme}" 16}
${generateIconPNG "${colorScheme}" 32}
${generateIconPNG "${colorScheme}" 48}
${generateIconPNG "${colorScheme}" 64}
${generateIconPNG "${colorScheme}" 120}
${generateIconPNG "${colorScheme}" 152}
${generateIconPNG "${colorScheme}" 167}
${generateIconPNG "${colorScheme}" 180}
${generateIconPNG "${colorScheme}" 192}
          '';
          generateIconsLiquid = colorScheme: "${lib.getExe patternReplace} ./data/icons.liquid ./_includes/generated/icons/${colorScheme}.liquid ./data/replacePatterns/icon-liquid/${colorScheme}.csv";
        in writeShellScriptBin "generate" ''
echo "Cleaning images..."
rm -rf ${imagesLocation}/*

echo "Generating images..."
mkdir -p ${imagesLocation}/icons/dark
TmpDir=$(mktemp -d)
${inkscapeExport "-C" "./data/favicon-source.svg" "$TmpDir/template.svg"}
${generateIconsColorScheme "dark"}
rm -rf $TmpDir

mkdir -p ${imagesLocation}/badges
cp ./data/valid-rss-rogers.png ${imagesLocation}/badges/valid-rss.png
cp ./data/vcss.png ${imagesLocation}/badges/valid-css.png
${inkscapeExport "-C -h 31" "./data/ai-label_banner-no-ai-used.svg" "${imagesLocation}/badges/no-ai.png"}

echo "Cleaning styles..."
rm -rf ./styles/*

echo "Generating styles..."
cp ./data/style.css ./styles/style.css
${lib.getExe stripCSS} ./styles/catppuccin.css ./data/catppuccin.css ./styles/style.css

echo "Cleaning generated includes..."
rm -rf ./_includes/generated/*

echo "Generating includes..."
mkdir -p ./_includes/generated/icons
${generateIconsLiquid "dark"}
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
        patternReplace = writeScriptBin "pattern-replace" ''
#!${lib.getExe nushell}

def main [
  inputFile: string
  outputFile: string
  paternsFile: string
] {
  let paterns = open --raw $paternsFile | from csv;
  mut data = open $inputFile;

  for $pattern in $paterns {
    $data = $data | str replace -a $pattern.pattern $pattern.replace;
  }

  $data | save $outputFile;
}
        '';

        build = writeShellScriptBin "build" ''
${lib.getExe generate}

echo "Cleaning local folder..."
rm -rf ./_site/*

echo "Building new site..."
${lib.getExe cobalt} build --no-drafts --quiet
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
        patternReplace

        build
        upload
        serve
      ];
    };
  });
}