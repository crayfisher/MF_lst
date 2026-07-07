# GWchart — MODFLOW listing file reader & visualiser

> **Beta.** This app is under active development; expect rough edges and please
> report bugs (see below).

MODFLOW listing file reader and **interactive, Shiny-based visualiser**. Upload,
parse, and dynamically analyse water budget calculations, solver convergence
performance, and time-step execution details from MODFLOW listing
(`.lst` / `.list` / `.out` / `.txt`) files.

Inspired by USGS
[GW_Chart](https://www.usgs.gov/software/gwchart-a-program-creating-specialized-graphs-used-groundwater-studies).
Part of the [Crayfisher](https://crayfisher.com) suite of web-based groundwater
modelling tools. Live: **https://lst.crayfisher.com**

## Features

- **Bundled demo data** — a demo selector loads sample HPM listing files instantly
  (no upload needed); any `.lst`/`.list`/`.txt`/`.out` dropped into `demo/` is
  auto-discovered
- Upload one or more listing files and compare runs
- Water-budget plots: **rate** or **cumulative**, with unit conversion
  (m³/d, L/s, GL/a) and a custom multiplier (e.g. cross-section)
- Per-term selection (IN / OUT / OTHER), time axis in days / date / stress period
- Table view with export

## Run locally

```r
shiny::runApp("app.R")
```

Model/listing parsing uses Python (flopy) via `reticulate`; in Docker this is the
bundled `flopy_env` conda environment.

## Run with Docker

```bash
docker build -t rgw_chart_app .
docker run -d --restart unless-stopped --name rgw_chart -p 127.0.0.1:3838:3838 rgw_chart_app
```

See `DEPLOYMENT.md` for the full deploy/redeploy reference (covers both this app
and the companion [GWheads / MF_heads](https://github.com/crayfisher/MF_heads)
heads visualiser).

## Acknowledgements

This app is **powered by [FloPy](https://github.com/modflowpy/flopy)** — the Python
package for creating, running, and post-processing MODFLOW models — which it uses
(via `reticulate`) to parse MODFLOW listing files. If you use this tool in your
work, please also cite FloPy:

> Bakker, M., Post, V., Langevin, C.D., Hughes, J.D., White, J.T., Starn, J.J.,
> and Fienen, M.N. (2016). Scripting MODFLOW Model Development Using Python and
> FloPy. *Groundwater*, 54(5), 733–739. https://doi.org/10.1111/gwat.12413

## Reporting bugs

Please open an issue: https://github.com/crayfisher/MF_lst/issues
