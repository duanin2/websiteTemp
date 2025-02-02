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
          imagesLocation = "images";

          sizeToSizeString = size: "${toString size}x${toString size}";
          getLargestElement = array: (builtins.elemAt (builtins.sort (a: b: a > b) array) 0);

          getIconLocation = colorScheme: width: type: "${imagesLocation}/icons/${colorScheme}/${toString width}.${type}";

          generateIcon = colorScheme: width: let
            SVGLocation = "${imagesLocation}/icons/${colorScheme}/any.svg";
            WebPLocation = getIconLocation colorScheme width "webp";
            PNGLocation = getIconLocation colorScheme width "png";
            JPEGLocation = getIconLocation colorScheme width "jpg";
            AVIFLocation = getIconLocation colorScheme width "avif";
            APNGLocation = getIconLocation colorScheme width "apng";
            GIFLocation = getIconLocation colorScheme width "gif";
          in ''
${inkscapeExport "-C -w ${toString width} -h ${toString width}" SVGLocation PNGLocation}
${lib.getExe imagemagick} ${PNGLocation} ${WebPLocation}
${lib.getExe imagemagick} ${PNGLocation} ${JPEGLocation}
${lib.getExe imagemagick} ${PNGLocation} ${AVIFLocation}
${lib.getExe imagemagick} ${PNGLocation} ${APNGLocation}
${lib.getExe imagemagick} ${PNGLocation} ${GIFLocation}
          '';
          generateIconsColorScheme = colorScheme: ''
${lib.getExe patternReplace} $TmpDir/template.svg ${imagesLocation}/icons/${colorScheme}/any.svg data/replacePatterns/icon-svg/${colorScheme}.csv
${builtins.concatStringsSep "\n" (map (generateIcon "${colorScheme}") iconSizes)}
${lib.getExe imagemagick} ${builtins.concatStringsSep " " (map (width: getIconLocation colorScheme width "png") iconSizes)} ./favicon.ico
${if (builtins.length appleTouchIconSizes) > 0 then "cp ${getIconLocation colorScheme (getLargestElement appleTouchIconSizes) "png"} ./apple-touch-icon.png" else ""}
          '';
          generateIconsLiquid = colorScheme: "${lib.getExe patternReplace} ${iconsLiquidTemplate} _includes/generated/icons/${colorScheme}.liquid ./data/replacePatterns/icon-liquid/${colorScheme}.csv";
          appleTouchIconSizes = builtins.sort (a: b: a > b) [ 180 167 152 120 ];
          iconSizes = builtins.sort (a: b: a > b) (appleTouchIconSizes ++ [ 192 64 48 32 16 ]);
          iconsLiquidTemplate = writeText "icons.liquid" ''
<link rel="icon" type="image/svg+xml" sizes="any" href="/images/icons/{{ color-scheme }}/any.svg">
${builtins.concatStringsSep "\n" (map (size: builtins.concatStringsSep "\n" (map (type: "<link rel=\"icon${if (builtins.elem size appleTouchIconSizes) then " apple-touch-icon" else ""}\" type=\"${type.type}\" sizes=\"${sizeToSizeString size}\" href=\"/${getIconLocation "{{ color-scheme }}" size type.ext}\">") [ {type = "image/avif"; ext = "avif";} {type = "image/webp"; ext = "webp";} {type = "image/apng"; ext = "apng";} {type = "image/png"; ext = "png";} {type = "image/jpg"; ext = "jpg";} {type = "image/gif"; ext = "gif";} ])) iconSizes)}
<link rel="icon apple-touch-icon" type="image/png" sizes="${sizeToSizeString (getLargestElement appleTouchIconSizes)}" href="/apple-touch-icon.png">
${builtins.concatStringsSep "\n" (map (type: "<link rel=\"icon\" type=\"${type}\" sizes=\"${builtins.concatStringsSep " " (map sizeToSizeString iconSizes)}\" href=\"/favicon.ico\">") [ "image/vnd.microsoft.icon" "image/x-icon" ])}
          '';
        in writeShellScriptBin "generate" ''
echo "Creating the temporary directory..."
TmpDir=$(mktemp -d)

echo "Cleaning images..."
rm -rf ${imagesLocation}/* favicon.ico apple-touch-icon.png
mkdir -p ${imagesLocation}/{icons/dark,badges}

echo "Cleaning styles..."
rm -rf styles/*

echo "Cleaning generated includes..."
rm -rf _includes/generated/*
mkdir -p _includes/generated/icons

echo "Generating images..."
${inkscapeExport "-C -l" "./data/favicon-source.svg" "$TmpDir/template.svg"}
${generateIconsColorScheme "dark"}

cp data/valid-rss-rogers.png ${imagesLocation}/badges/valid-rss.png
cp data/vcss.png ${imagesLocation}/badges/valid-css.png
${inkscapeExport "-C -h 31" "data/ai-label_banner-no-ai-used.svg" "${imagesLocation}/badges/no-ai.png"}

rm -rf $TmpDir/*

echo "Generating styles..."
cp data/style.css styles/style.css
${lib.getExe stripCSS} styles/catppuccin.css data/catppuccin.css styles/style.css

rm -rf $TmpDir/*

echo "Generating includes..."
${generateIconsLiquid "dark"}

rm -rf $TmpDir/*

echo "Cleaning the temporary directory..."
rmdir $TmpDir
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

				ffmpeg
        inkscape
        imagemagick

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