#!/usr/bin/env bash 
set -e

eval `opam config -env`

# ./openvpn_append_device.sh haris.d2 debian.d2 signpo.st haris.d2.signpo.st conf/ tmp/
local_node=$1
remote_node=$2
domain=$3
dst_domain=$4
conf_dir=$5
tmp_dir=$6
ns_ip=$7
ns_port=$8

# create tmp folder
remote_host=$remote_node.$domain
local_host=$local_node.$domain
dst_dir=$tmp_dir/$local_host/

if [ ! -e $dst_dir ]; then 
  echo "Missing folder $dst_dir"
  exit 1
fi

# sign the remote domain certificate
crypto-convert \
  -p $conf_dir/signpost.pem  \
  -d 30758400 \
  -s "C=UK,O=signpost,CN=$remote_host," \
  -i "C=UK,O=signpost,CN=$local_host," \
  -S $ns_ip \
  -P $ns_port \
  SIGN \
  $remote_host \
  DNS_PUB \
  $dst_dir/allowed-$remote_host.crt \
  PEM_CERT

cat $dst_dir/tmp.crt $dst_dir/allowed-*.crt > $dst_dir/ca.crt
