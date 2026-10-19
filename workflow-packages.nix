# Install only the agent and tools declared by a workflow image.
{ pkgs ? import ./workflow-nixpkgs.nix }:

let
  agent = builtins.getEnv "AGENTSBOX_AGENT";
  names = builtins.filter (name: builtins.isString name && name != "")
    (builtins.split "[ \n\t]+" (builtins.getEnv "AGENTSBOX_TOOLS"));
  agents = {
    claude = (import ./claude-code.nix { inherit pkgs; }).claude-code;
    codex = (import ./codex.nix { inherit pkgs; }).codex;
    pi = (import ./pi.nix { inherit pkgs; }).pi-coding-agent;
    opencode = (import ./opencode.nix { inherit pkgs; }).opencode;
  };
in
pkgs.buildEnv {
  name = "agentsbox-workflow-tools";
  paths = (with pkgs; [ bash cacert coreutils gitMinimal jq ripgrep ])
    ++ [ (builtins.getAttr agent agents) ]
    ++ (map (name: builtins.getAttr name pkgs) names);
  ignoreCollisions = true;
}
