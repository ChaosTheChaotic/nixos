{ colors }:
let
  c = colors.withHashtag;
in
{
  inherit (c)
    base00
    base01
    base02
    base03
    base04
    base05
    base06
    base07
    base08
    base09
    base0A
    base0B
    base0C
    base0D
    base0E
    base0F
    ;

  base = c.base00;
  surface = c.base01;
  overlay = c.base02;
  muted = c.base03;
  subtle = c.base04;
  text = c.base05;
  love = c.base08;
  gold = c.base09;
  rose = c.base0A;
  pine = c.base0B;
  foam = c.base0C;
  iris = c.base0D;

  # Rose pine moon extended (not in base16 for some reason)
  highlightLow = "#2a283e";
  highlightMed = "#44415a";
  highlightHigh = "#56526e";

  # Normal rose pine
  rosePine = {
    base = "#191724";
    surface = "#1f1d2e";
    overlay = "#26233a";
    muted = "#6e6a86";
    subtle = "#908caa";
    text = "#e0def4";
    love = "#eb6f92";
    gold = "#f6c177";
    rose = "#ebbcba";
    pine = "#31748f";
    foam = "#9ccfd8";
    iris = "#c4a7e7";
    highlightLow = "#21202e";
    highlightMed = "#403d52";
    highlightHigh = "#524f67";
  };
}
