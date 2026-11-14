# Astra Atlas

A responsive planetary exploration workspace for comparing named locations on Mars and the Moon.

## Run

```sh
npm install
npm run dev
```

Run `npm run build` for a production build and `npm run lint` for Oxlint.

## PostgreSQL schema

The PostgreSQL + PostGIS schema is in [`database/schema.sql`](./database/schema.sql).
Create a database with PostgreSQL and apply it with `psql -d <database_name> -f database/schema.sql`.
The database user needs permission to install the `postgis` and `pgcrypto` extensions.

## What Works

- Switch between Mars and the Moon; select landmarks from the list or approximate equirectangular coordinate plot.
- Retrieve image records from the public NASA Images API. A record is displayed only when its metadata explicitly mentions the selected feature. NASA ID, creator, date, and record link are retained.
- Rank cross-world candidates using the Jaccard overlap of curated morphology tags. The percentage is a derived taxonomy score, not a measured terrain similarity.
- Compare the selected pair and ask the built-in source-bound assistant about morphology, comparisons, or data availability.
- Open NASA Mars Trek or Moon Trek for interactive, instrument-backed surface exploration.

## Provenance And Limits

- The coordinate plot is schematic. Feature-center coordinates are approximate anchors; they are not a navigable basemap or a terrain product. Feature names and reference links point to the [USGS / IAU Gazetteer](https://planetarynames.wr.usgs.gov/).
- Imagery and its metadata come from the [NASA Images and Video Library API](https://images.nasa.gov/). API search can return broad context imagery; displayed records must mention the feature, and the NASA record remains the source of truth.
- No MOLA or LOLA digital elevation model is sampled in this version. Elevation, slope, derived terrain statistics, and exploration-risk values are intentionally not shown. The [NASA Planetary Data System](https://pds.nasa.gov/) and official [NASA Mars Trek](https://trek.nasa.gov/mars/) / [Moon Trek](https://trek.nasa.gov/moon/) are linked as next-step data tools.
- The assistant is deterministic and retrieval-based, not a generative AI model. No API key is needed. A hosted language model would require a backend, key management, and source-grounding controls.
- Twin tags are a small curated demonstration index. A scientifically defensible terrain matcher still needs versioned, co-registered MOLA / LOLA elevation products, slope derivation, resolution normalization, and a validated morphology ontology.
