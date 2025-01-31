# My current website source code

- built with cobalt and a bunch of scripts in a nix flake

## How to build

- Install nix
- `nix develop` in the root of the repository (or just use direnv like me)
- you can now build the website using:
	- `build` to build the site from source locally
	- `serve` to start a local HTTP server
	- `generate` to regenerate the contents of `./images` and `./styles` directories from the contents of the `./data` directory