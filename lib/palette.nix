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
}
