# The Digital Divide in India — NSS 79th Round CAMS (2022-23)

Coursework, B.A. Economics, Christ University.
Report: `digital-divide-india.Rmd` (knit to HTML).

## Files
| File | Purpose |
|---|---|
| `digital-divide-india.Rmd` | The report (descriptive charts + regression analysis) |
| `prepare_data.R` | Turns the huge raw CSVs into two small `.rds` files (run once, locally) |
| `data/*.rds` | Slim analysis data (committed to GitHub) |
| `data-raw/` | Raw MoSPI CSVs — **not** committed (see `.gitignore`) |
| `manifest.json` | Package list Connect Cloud needs (generated, see below) |

## Steps to publish on Posit Connect Cloud
1. Put the 3 raw CSVs in `data-raw/`, then run `source("prepare_data.R")`.
   Check `data/` is well under 100 MB (GitHub's file limit).
2. Knit `digital-divide-india.Rmd` locally. If it knits, it will deploy.
3. In the R console, from this project folder:
   `install.packages("rsconnect"); rsconnect::writeManifest()`
   (re-run whenever you add or change a package).
4. Create a **public** GitHub repo and push everything except `data-raw/`.
5. At connect.posit.cloud: Publish -> from GitHub -> choose the repo ->
   primary file `digital-divide-india.Rmd` -> Publish.
