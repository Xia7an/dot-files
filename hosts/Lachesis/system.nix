{ ... }: {
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/homebrew.nix
    ../../modules/darwin/launch-agents.nix
  ];

  networking.hostName = "Lachesis";
  networking.localHostName = "INOYU-MacBookPro";
  networking.computerName = "混沌を超えし我らが神聖なる調律主のMacBook Pro";
  system.primaryUser = "inoyu";
}
