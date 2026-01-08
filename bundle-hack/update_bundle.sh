#!/usr/bin/env bash

export MARIN3R_OPERATOR_IMAGE_PULLSPEC="quay.io/integreatly/marin3r-operator:v0.13.3"

export CSV_FILE=/manifests/marin3r.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale-sre/marin3r:v.*|\"${MARIN3R_OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv using PyYAML
python3 - << CSV_UPDATE
import os
from sys import exit as sys_exit
from datetime import datetime, timezone
import yaml

def load_manifest(pathn: str):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.safe_load(f)
   except FileNotFoundError:
      print("File can not found")
      sys_exit(2)

def dump_manifest(pathn: str, manifest):
   with open(pathn, "w") as f:
      yaml.safe_dump(manifest, f, default_flow_style=False, sort_keys=False)

timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp, tz=timezone.utc)
csv_file = os.getenv('CSV_FILE')
pullspec = os.getenv('MARIN3R_OPERATOR_IMAGE_PULLSPEC', '')
csv_manifest = load_manifest(csv_file)

# Add arch and os support labels
csv_manifest.setdefault('metadata', {}).setdefault('labels', {})
csv_manifest['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'

# Update annotations
csv_manifest['metadata'].setdefault('annotations', {})
csv_manifest['metadata']['annotations']['createdAt'] = datetime_time.strftime('%Y-%m-%dT%H:%M:%SZ')
csv_manifest['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
csv_manifest['metadata']['annotations']['repository'] = 'https://github.com/3scale-ops/marin3r'
csv_manifest['metadata']['annotations']['containerImage'] = pullspec
csv_manifest['metadata']['annotations']['features.operators.openshift.io/cnf'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/cni'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/csi'] = 'false'
csv_manifest['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'

# Set replaces
csv_manifest.setdefault('spec', {})
csv_manifest['spec']['replaces'] = 'marin3r.v0.13.2'

dump_manifest(csv_file, csv_manifest)
CSV_UPDATE

cat $CSV_FILE