{
  description = "rdlucas2 nixcfg";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    {
      nixosConfigurations.pi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          ./hosts/pi
        ];
      };
    };
}
