# mmtoolbox.github.io

Source for **<https://mmtoolbox.github.io>**: tool comparisons, reports and
documentation from the MMToolbox community.

## Run it locally

1. [Install Quarto](https://quarto.org/docs/get-started/). The CI uses the version in
   [`.github/tool-versions.env`](.github/tool-versions.env). Any recent version
   works for previewing.
2. Run:

   ```bash
   quarto preview
   ```

Push to `main` (or merge a PR) and the site deploys automatically.

## Layout

```
_quarto.yml          site config: navigation, theme, footer
index.qmd            home page
tools/ reports/ docs/  a directory for each section on the site
data/                CSV files used in tables (if required)
_templates/page.qmd  copy this to start a new page
_extensions/         the {{< csv-table >}} shortcode
.github/             build and deploy, and automated dependency updates
```

See the [Contributing page](https://mmtoolbox.github.io/contributing.html)
(`contributing.qmd`) for the full guide.

## Licence

Site content (text, data, images) is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The code (build
scripts, extensions, styles) is under the MIT licence in [`LICENSE`](LICENSE).
