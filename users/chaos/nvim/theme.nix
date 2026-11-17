{ lib, vp, ... }:

let
  themes = [
    {
      name = "rose-pine";
      display = "RosePine";
    }
    {
      name = "tokyonight";
      display = "TokyoNight";
    }
    {
      name = "silkcircuit";
      display = "silkcircuit";
    }
  ];

  vimList = l: "[" + lib.concatMapStringsSep ", " (s: "'${s}'") l + "]";

  transparentGroups = [
    "Normal"
    "NormalNC"
    "LineNr"
    "Folded"
    "NonText"
    "SpecialKey"
    "VertSplit"
    "SignColumn"
    "EndOfBuffer"
  ];
in
{
  extraPlugins = [ vp.silkcircuit-nvim ];

  colorschemes = {
    tokyonight = {
      enable = true;
      package = vp.tokyonight-nvim;
      settings = {
        style = "night";
        transparent = true;
        terminal_colors = true;
      };
    };
    rose-pine = {
      enable = true;
      package = vp.rose-pine;
      settings = {
        variant = "moon";
        dim_inactive_windows = false;
        enable.terminal = true;
        styles.transparency = true;
      };
    };
  };

  # Label to ensure that multiple enabled colorschemes cannot fight over it
  colorscheme = "rose-pine";

  # highlight updates a group (keeps the themes fg)
  # the old nvim_set_hl(..., { bg = "NONE" }) replaced the whole group
  autoCmd = [
    {
      event = "ColorScheme";
      pattern = "*";
      command = lib.concatStringsSep " | " (
        map (g: "highlight ${g} guibg=NONE ctermbg=NONE") transparentGroups
        ++ [ "highlight! link GitSignsCurrentLineBlame Comment" ]
      );
    }
  ];

  # Plain Vimscript, generated from themes above.
  extraConfigVim = ''
    let g:themes = ${vimList (map (t: t.name) themes)}
    let g:theme_displays = ${vimList (map (t: t.display) themes)}
    let g:current_theme = 0

    function! ThemeApply(idx) abort
      let g:current_theme = a:idx
      execute 'colorscheme ' . g:themes[a:idx]
      echo 'Theme set to: ' . g:theme_displays[a:idx]
    endfunction

    function! ThemeToggle() abort
      call ThemeApply((g:current_theme + 1) % len(g:themes))
    endfunction

    function! ThemeSet(input) abort
      let l:needle = tolower(a:input)
      let l:matches = filter(range(len(g:theme_displays)), {_, i -> stridx(tolower(g:theme_displays[i]), l:needle) >= 0})
      if empty(l:matches)
        echohl ErrorMsg | echo "Error: No theme found matching " . string(a:input) | echohl None
      elseif len(l:matches) > 1
        echohl ErrorMsg | echo "Error: Multiple themes match " . string(a:input) . ":" | echohl None
        for l:i in l:matches
          echo '  - ' . g:theme_displays[l:i]
        endfor
      else
        call ThemeApply(l:matches[0])
      endif
    endfunction

    function! ThemeComplete(arglead, cmdline, cursorpos) abort
      return filter(copy(g:theme_displays), {_, v -> stridx(tolower(v), tolower(a:arglead)) >= 0})
    endfunction

    command! ToggleTheme call ThemeToggle()
    command! -nargs=1 -complete=customlist,ThemeComplete SetTheme call ThemeSet(<q-args>)
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>tt";
      action = "<cmd>ToggleTheme<CR>";
      options = {
        silent = true;
        desc = "Toggle color theme";
      };
    }
  ];
}
