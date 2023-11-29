# OpenProject Helm Charts

This is a self-contained Helm chart registry for OpenProject based on github pages
using helm's [chart-releaser](https://github.com/helm/chart-releaser-action) action.



## Installation

Please refer to our [documentation](https://www.openproject.org/docs/installation-and-operations/installation/helm-chart/) for instructions on how to install the OpenProject helm chart.


## Helm chart signing

We sign our chart using the [Helm Provenance and Integrity](https://helm.sh/docs/topics/provenance/) functionality. You can find the used public key here

-  https://github.com/opf/helm-charts/blob/main/signing.key 
- https://keys.openpgp.org/vks/v1/by-fingerprint/CB1CA0488A75B7471EA1B087CF56DD6A0AE260E5


# Contribution

We welcome all contributions. For the release management, we're using the [changeset action](https://github.com/changesets/action) to generate the changelog and maintain the release process.