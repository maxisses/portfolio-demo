# Localnews (Golden Path der Portfolio-Demo)

Basis ist die Localnews-App aus [maxisses/ice-demo](https://github.com/maxisses/ice-demo)
(Commit `c4fe2e4`), ursprünglich aus dem Buch "Kubernetes Native Development". Ergänzt um:

- `location-extractor`: Ortserkennung wahlweise über ein Modell hinter Models-as-a-Service
  (`EXTRACTOR=llm`, Zugang über `MAAS_BASE_URL`, `MAAS_API_KEY`, `MAAS_MODEL`), mit spaCy als
  Rückfall. Gebaut im Cluster (`gitops/components/localnews-build`).
- `chart`: Schalter `externalDatabase` (verwaltete PostgreSQL aus dem Katalog statt eingebauter
  PostGIS) und `llm` (MaaS-Secret an den Location-Extractor).

Bereitgestellt wird die App über das Katalog-Item "App bereitstellen: Localnews".
