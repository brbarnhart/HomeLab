{
	description = "Homelab flake";

	inputs = {
	  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	  nixarr.url = "github:nix-media-server/nixarr";
	  nixarr.inputs.nixpkgs.follows = "nixpkgs";
	};

	outputs = { self, nixpkgs, nixarr }:
	let
		system = "x86_64-linux";

		pkgs = import nixpkgs {
			inherit system;

			config = {
				allowUnfree = true;
			};
		};

	in {
		nixosConfigurations = {
			HomeServer = nixpkgs.lib.nixosSystem {
				specialArgs = { inherit system; };

				modules = [
					./configuration.nix
					./hardware-configuration.nix
					nixarr.nixosModules.default
				];
			};
		};
	};
}
