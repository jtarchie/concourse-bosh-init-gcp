#!/bin/bash

set -eux

export project_id=$1 region=us-east1 zone=us-east1-d
export service_account_email=terraform@${project_id}.iam.gserviceaccount.com
shift

gcloud config set compute/zone $zone
gcloud config set compute/region $region

command="create"
password="password"
while getopts ":dp:" o; do
  case "${o}" in
    d)
      command="destroy"
      ;;
    p)
      password="$OPTARG"
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
    ?)
      echo "Unimplemented option: -$OPTARG"
      exit 1
  esac
done

keys_filename="$(pwd)/build/concourse.key.json"
if [ ! -e "$keys_filename" ]; then
  echo "create a user"
  exit 1
fi

export GOOGLE_CREDENTIALS=$(cat "$keys_filename")

function run_terraform() {
  pushd build/
    terraform $1 \
      -var "projectid=$project_id" \
      -var "zone=$zone" \
      -var "region=$region" \
      ../
  popd
}

function run_bosh() {
  pushd build/
    bosh $1 ../manifest.yml \
      --state manifest-state.json \
      -v "password=$password" \
      -v "zone=$zone" \
      -v "user=$(whoami)" \
      -v "network_name=$(cat terraform.tfstate | jq -r '.modules[0].resources."google_compute_network.network".primary.attributes.name')" \
      -v private_key=~/.ssh/google_compute_engine \
      -v json_key="$(cat $keys_filename | jq @json)" \
      -v "project_id=$project_id" \
      -v "static_ip=$(cat terraform.tfstate | jq -r '.modules[0].resources."google_compute_address.concourse".primary.attributes.address')" \
      -v "subnetwork_name=$(cat terraform.tfstate | jq -r '.modules[0].resources."google_compute_subnetwork.concourse-public-subnet-1".primary.attributes.name')"
  popd
}

if [ "$command" == "destroy" ]; then
  run_bosh "delete-env"
  run_terraform "destroy"
else
  run_terraform "apply"
  run_bosh "create-env"
fi

