{pkgs, ...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Inoyu";
        email = "inoyu0329@gmail.com";
      };
    };
  };

  programs.gh = {
    enable = true;
    extensions = with pkgs; [gh-markdown-preview];
    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  home.packages = with pkgs; [
    ghq
    fzf
    peco
    tig
    serie
  ];

  programs.git.settings.ghq.root = "~/Gits";

  programs.fish.shellInit = ''
    function peco_src
        set -l query (commandline)
        set -l selected_dir (ghq list -p | fzf --prompt="repositories >" --query "$query")
        if test -n "$selected_dir"
            commandline "cd $selected_dir"
            commandline -f execute
        end
        commandline -f repaint
    end
    bind \c] peco_src

    function peco_remote
        set -l query (commandline)
        set -l selected_dir (ghq get (gh api --paginate /user/repos --jq '.[].clone_url' | fzf))
        if test -n "$selected_dir"
            commandline "cd $selected_dir"
            commandline -f execute
        end
        commandline -f repaint
    end
    bind ctrl-shift-\\ peco_remote
  '';
}
