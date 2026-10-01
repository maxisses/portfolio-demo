# Localnews (golden path of the portfolio demo)

This is the Localnews app from [maxisses/ice-demo](https://github.com/maxisses/ice-demo)
(commit `c4fe2e4`), which started out in the book "Kubernetes Native Development". We added
two things:

- `location-extractor` can find locations through a model behind Models-as-a-Service
  (`EXTRACTOR=llm`, access through `MAAS_BASE_URL`, `MAAS_API_KEY`, `MAAS_MODEL`) and falls
  back to spaCy if the model doesn't answer. It's built in the cluster
  (`gitops/components/localnews-build`).
- `chart` has the switches `externalDatabase` (a managed PostgreSQL from the catalog instead of
  the built-in PostGIS) and `llm` (the MaaS secret for the location extractor).

App teams deploy it through the catalog item "Catalog: Deploy App (Localnews)".
