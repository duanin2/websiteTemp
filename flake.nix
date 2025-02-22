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

        fileExtToMIME = {
          webp = "image/webp";
          png = "image/png";
          jpg = "image/jpeg";
          avif = "image/avif";
          apng = "image/apng";
          gif = "image/gif";
          jxl = "image/jxl";
          svg = "image/svg";
        };
        fileExtToMIMEBash = writeShellScriptBin "file-ext-to-mime" ''
case "$1" in
  ${builtins.concatStringsSep "\n  " (lib.mapAttrsToList (name: value: "*.${name})\n    echo \"${value}\";\n    exit 0\n    ;;") fileExtToMIME)}
  *)
    echo "text/plain";
    exit 255;
    ;;
esac
        '';

        generate = let
          imagesLocation = "images";

          sizeToSizeString = size: "${toString size}x${toString size}";

          sortAscending = array: (builtins.sort (a: b: a < b) array);
          sortDescending = array: (builtins.sort (a: b: a > b) array);
          getFirstElement = array: builtins.elemAt array 0;
          getLargestElement = array: getFirstElement (sortDescending array);
          getSmallestElement = array: getFirstElement (sortAscending array);

          generateImage = source: targetDirectory: fileName: formats: let
            formatsLocations = builtins.mapAttrs (type: _: "${targetDirectory}/${fileName}.${type}") formats;

            sortedFiles = "_data/images";
            sortedFile = "${sortedFiles}/${builtins.replaceStrings [ "/" ] [ "-" ] targetDirectory}-${fileName}.yml";
          in ''
${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${lib.getExe imagemagick} ${source} -strip ${toString value} ${formatsLocations.${name}} 2> /dev/null || rm -f ${formatsLocations.${name}}") formats)}
for file in $(ls -Sr ${builtins.concatStringsSep " " (lib.mapAttrsToList (_: value: "\"${value}\"") formatsLocations)} 2> /dev/null); do
  echo -e "- name: $file\n  type: $(${lib.getExe fileExtToMIMEBash} $file)" >> ${sortedFile}
done
          '';
          generateImageFromSVG = extraParams: source: targetDirectory: name: generatorFunction: let
            SVGFile = "${targetDirectory}/${name}.svg";
            PNGFile = "${targetDirectory}/${name}.png";

            sortedFile = "_data/images/${builtins.replaceStrings [ "/" ] [ "-" ] targetDirectory}-${name}.yml";
          in ''
${inkscapeExport "${extraParams} -l" source SVGFile}
${inkscapeExport extraParams source PNGFile}
${generatorFunction PNGFile targetDirectory name}
echo -e "- name: ${SVGFile}\n  type: $(${lib.getExe fileExtToMIMEBash} ${SVGFile})" >> ${sortedFile}
          '';
          generateStaticImage = source: targetDirectory: name: generateImage source targetDirectory name {
            webp = "-quality 0";
            png = "-define PNG:compression-level=9";
            jpg = "-quality 50";
            avif = "";
            apng = "-define PNG:compression-level=9";
            gif = "";
            jxl = "-quality 50";
          };
          generateTransparentImage = source: targetDirectory: name: generateImage source targetDirectory name {
            webp = "-quality 0";
            png = "-define PNG:compression-level=9";
            avif = "";
            apng = "-define PNG:compression-level=9";
            gif = "";
            jxl = "-quality 50";
          };
          generateAnimatedImage = source: targetDirectory: name: generateImage source targetDirectory name {
            webp = "-quality 0";
            # avif = "";
            apng = "-define PNG:compression-level=9";
            gif = "";
            jxl = "-quality 50";
          };

          getIconLocation = colorScheme: width: type: "${imagesLocation}/icons/${colorScheme}/${toString width}.${type}";

          generateIcon = colorScheme: width: let
            SVGLocation = "${imagesLocation}/icons/${colorScheme}/any.svg";
            PNGLocation = getIconLocation colorScheme width "png";
          in ''
${inkscapeExport "-C -w ${toString width} -h ${toString width}" SVGLocation PNGLocation}
${generateStaticImage PNGLocation "${imagesLocation}/icons/${colorScheme}" (toString width)}
          '';
          generateIconsColorScheme = colorScheme: ''
${lib.getExe patternReplace} $TmpDir/template.svg ${imagesLocation}/icons/${colorScheme}/any.svg data/replacePatterns/icon-svg/${colorScheme}.csv
${builtins.concatStringsSep "\n" (map (generateIcon "${colorScheme}") iconSizes)}
${lib.getExe imagemagick} ${getIconLocation colorScheme (getSmallestElement iconSizes) "png"} favicon.ico
${if (builtins.length appleTouchIconSizes) > 0 then "cp ${getIconLocation colorScheme (getLargestElement appleTouchIconSizes) "png"} apple-touch-icon.png" else ""}
          '';
          generateIconsLiquid = colorScheme: "${lib.getExe patternReplace} ${iconsLiquidTemplate} _includes/generated/icons/${colorScheme}.liquid data/replacePatterns/icon-liquid/${colorScheme}.csv";
          appleTouchIconSizes = sortAscending [ 180 167 152 120 ];
          iconSizes = sortAscending (appleTouchIconSizes ++ [ 192 64 48 32 16 ]);
          iconsLiquidTemplate = writeText "icons.liquid" ''
<link rel="icon" type="image/svg+xml" sizes="any" href="/images/icons/{{ color-scheme }}/any.svg">
${builtins.concatStringsSep "\n" (map (size: "{% for file in site.data.images.images-icons-dark-${toString size} %}<link rel=\"icon${if (builtins.elem size appleTouchIconSizes) then " apple-touch-icon" else ""}\" sizes=\"${sizeToSizeString size}\" href=\"{{ file.name }}\" type=\"{{ file.type }}\">{% endfor %}") iconSizes)}
<link rel="icon apple-touch-icon" type="image/png" sizes="${sizeToSizeString (getLargestElement appleTouchIconSizes)}" href="/apple-touch-icon.png">
${builtins.concatStringsSep "\n" (map (type: "<link rel=\"icon\" type=\"${type}\" sizes=\"${sizeToSizeString (getSmallestElement iconSizes)}\" href=\"/favicon.ico\">") [ "image/vnd.microsoft.icon" "image/x-icon" ])}
          '';
        in writeShellScriptBin "generate" ''
echo "Creating the temporary directory..."
TmpDir=$(mktemp -d)

echo "Cleaning images..."
rm -rf ${imagesLocation}/* favicon.ico apple-touch-icon.png
mkdir -p ${imagesLocation}/{icons/dark,buttons,blinkies,badges}
rm -rf _data/images/*
mkdir -p _data/images/

echo "Cleaning styles..."
rm -rf styles/*

echo "Cleaning generated includes..."
rm -rf _includes/generated/*
mkdir -p _includes/generated/icons

echo "Generating images..."
${inkscapeExport "-C -l" "data/images/icons/favicon-source.svg" "$TmpDir/template.svg"}
${generateIconsColorScheme "dark"}

${generateTransparentImage "data/images/buttons/valid-rss-rogers.png" "${imagesLocation}/buttons" "valid-rss"}
${generateTransparentImage "data/images/buttons/vcss.png" "${imagesLocation}/buttons" "valid-css"}
${generateImageFromSVG "-C -h 31" "data/images/buttons/ai-label_banner-no-ai-used.svg" "${imagesLocation}/buttons" "no-ai" generateStaticImage}
${generateAnimatedImage "data/images/buttons/anything_but_chrome.gif" "${imagesLocation}/buttons" "anything-but-chrome"}
${generateStaticImage "data/images/buttons/firefox_now.png" "${imagesLocation}/buttons" "firefox-now"}
${generateAnimatedImage "data/images/buttons/blinkiesCafe-badge.gif" "${imagesLocation}/buttons" "blinkiesCafe"}
${generateStaticImage "data/images/buttons/green-team.gif" "${imagesLocation}/buttons" "green-team-512kb-club"}

${generateAnimatedImage "data/images/blinkies/blinkiesCafe-qX.gif" "${imagesLocation}/blinkies" "i-love-miku"}
${generateAnimatedImage "data/images/blinkies/blinkiesCafe-RX.gif" "${imagesLocation}/blinkies" "adhd"}
${generateAnimatedImage "data/images/blinkies/blinkiesCafe-l4.gif" "${imagesLocation}/blinkies" "autism"}

${generateStaticImage "data/images/badges/europe_copy1.png" "${imagesLocation}/badges" "europe"}
${generateStaticImage "data/images/badges/firefox_copy4.gif" "${imagesLocation}/badges" "firefox"}
${generateStaticImage "data/images/badges/linux2.gif" "${imagesLocation}/badges" "linux"}
${generateStaticImage "data/images/badges/rss2.gif" "${imagesLocation}/badges" "rss2"}
${generateStaticImage "data/images/badges/thunderbird_copy1.gif" "${imagesLocation}/badges" "thunderbird"}

rm -rf $TmpDir/*

echo "Generating styles..."
cp data/styles/style.css styles/style.css
${lib.getExe stripCSS} styles/catppuccin.css data/styles/catppuccin.css styles/style.css

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
        fileExtToMIMEBash

        build
        upload
        serve
      ];
    };
  });
}