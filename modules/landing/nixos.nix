{ ... }:
{
  # The landing page is a plain file in this repo, installed to a stable path
  # so niri's spawn-at-startup can point at it with a fixed file:// URL. Going
  # through /etc rather than the user's home keeps the path independent of the
  # username and makes it read-only, which is the intent: the repo is the
  # source of truth and edits belong in modules/landing/index.html.
  environment.etc."nixcfg/landing.html".source = ./index.html;
}
