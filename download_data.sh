#!/bin/sh
# Downloads the raw CSO baby names tables into data/.
set -e
mkdir -p data
curl -sSL -o data/VSA50.csv "https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/VSA50/CSV/1.0/en"
curl -sSL -o data/VSA60.csv "https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/VSA60/CSV/1.0/en"
echo "Downloaded data/VSA50.csv (boys) and data/VSA60.csv (girls)"
