#!/bin/sh
# Compiles the static site's stylesheet: hosts/site/site.input.css -> hosts/site/wwwroot/site.css (committed).
# Run it after changing a class in a .razor file of the site, in domains/content/site/ArticleBody.cs, in
# hosts/site/wwwroot/site.js or self-reflection.js, domains/content/site/SelfReflection.cs, or the input file itself (its @source lines list what is scanned). Needs the Tailwind CSS command-line tool, version 4, on PATH;
# the server build does not (it ships the committed file). hosts/site/tests/StylesheetTests.cs fails when a class in
# use has no rule in the committed file.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

if ! command -v tailwindcss >/dev/null 2>&1; then
  echo "site-css: tailwindcss is not on PATH (version 4 is needed)" >&2
  exit 2
fi

version=$(tailwindcss --help | head -n 1)
case "$version" in
  *"tailwindcss v4."*) ;;
  *)
    echo "site-css: Tailwind CSS version 4 is needed, found: $version" >&2
    exit 2
    ;;
esac

tailwindcss --input "$root/hosts/site/site.input.css" --output "$root/hosts/site/wwwroot/site.css"
echo "site-css: wrote hosts/site/wwwroot/site.css"
