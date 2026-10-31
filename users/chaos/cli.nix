{ palette, ... }:

{
  config = {
    programs = {
      bat.enable = true;
      fd = {
        enable = true;
        extraOptions = [
          "--no-ignore"
          "--absolute-path"
        ];
        hidden = true;
        ignores = [ ".git/" ];
      };
      aria2.enable = false;
      jq.enable = true;
      ripgrep-all.enable = false;
      ripgrep.enable = true;
      git = {
        enable = true;
        settings = {
          user = {
            name = "ChaosTheChaotic";
            email = "james.moriaty.ot@gmail.com";
          };
        };
        lfs.enable = true;
      };
      gh.enable = true;
      uv.enable = true;
      lazygit = {
        enable = true;
        enableZshIntegration = true;
      };
      eza = {
        enable = true;
        colors = "always";
        enableZshIntegration = true;
        icons = "auto";
        theme = {
          colourful = true;
          filekinds = {
            normal.foreground = palette.text;
            directory.foreground = palette.foam;
            symlink.foreground = palette.highlightHigh;
            pipe.foreground = palette.subtle;
            block_device.foreground = palette.rose;
            char_device.foreground = palette.gold;
            socket.foreground = palette.highlightLow;
            special.foreground = palette.iris;
            executable.foreground = palette.iris;
            mount_point.foreground = palette.highlightMed;
          };
          perms = {
            user_read.foreground = palette.subtle;
            user_write.foreground = palette.highlightMed;
            user_execute_file.foreground = palette.iris;
            user_execute_other.foreground = palette.iris;
            group_read.foreground = palette.subtle;
            group_write.foreground = palette.highlightMed;
            group_execute.foreground = palette.iris;
            other_read.foreground = palette.subtle;
            other_write.foreground = palette.highlightMed;
            other_execute.foreground = palette.iris;
            special_user_file.foreground = palette.iris;
            special_other.foreground = palette.highlightMed;
            attribute.foreground = palette.subtle;
          };
          size = {
            major.foreground = palette.subtle;
            minor.foreground = palette.foam;
            number_byte.foreground = palette.subtle;
            number_kilo.foreground = palette.highlightHigh;
            number_mega.foreground = palette.pine;
            number_giga.foreground = palette.iris;
            number_huge.foreground = palette.iris;
            unit_byte.foreground = palette.subtle;
            unit_kilo.foreground = palette.pine;
            unit_mega.foreground = palette.iris;
            unit_giga.foreground = palette.iris;
            unit_huge.foreground = palette.foam;
          };
          users = {
            user_you.foreground = palette.gold;
            user_root.foreground = palette.love;
            user_other.foreground = palette.iris;
            group_yours.foreground = palette.highlightHigh;
            group_other.foreground = palette.muted;
            group_root.foreground = palette.love;
          };
          links = {
            normal.foreground = palette.foam;
            multi_link_file.foreground = palette.pine;
          };
          git = {
            new.foreground = palette.foam;
            modified.foreground = palette.gold;
            deleted.foreground = palette.love;
            renamed.foreground = palette.pine;
            typechange.foreground = palette.iris;
            ignored.foreground = palette.muted;
            conflicted.foreground = palette.rose;
          };
          git_repo = {
            branch_main.foreground = palette.subtle;
            branch_other.foreground = palette.iris;
            git_clean.foreground = palette.foam;
            git_dirty.foreground = palette.love;
          };
          security_context = {
            colon.foreground = palette.subtle;
            user.foreground = palette.foam;
            role.foreground = palette.iris;
            typ.foreground = palette.muted;
            range.foreground = palette.iris;
          };
          file_type = {
            image.foreground = palette.gold;
            video.foreground = palette.love;
            music.foreground = palette.foam;
            lossless.foreground = palette.muted;
            crypto.foreground = palette.highlightMed;
            document.foreground = palette.subtle;
            compressed.foreground = palette.iris;
            temp.foreground = palette.rose;
            compiled.foreground = palette.pine;
            build.foreground = palette.muted;
            source.foreground = palette.rose;
          };
          punctuation.foreground = palette.highlightHigh;
          date.foreground = palette.pine;
          inode.foreground = palette.subtle;
          # was #9399B2 (Catppuccin) — no Rose-Pine equivalent; closest is subtle
          blocks.foreground = palette.subtle;
          header.foreground = palette.subtle;
          octal.foreground = palette.foam;
          flags.foreground = palette.iris;
          symlink_path.foreground = palette.foam;
          control_char.foreground = palette.pine;
          broken_symlink.foreground = palette.love;
          broken_path_overlay.foreground = palette.highlightHigh;
        };
      };
      btop = {
        enable = true;
        settings = {
          theme_background = false;
          truecolor = true;
          rounded_corners = true;
          terminal_sync = true;
        };
      };
    };
  };
}
