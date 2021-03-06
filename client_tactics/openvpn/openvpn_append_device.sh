#!/usr/bin/env bash 
set -e

eval `opam config -env`

# ./openvpn_append_device.sh haris.d2 debian.d2 signpo.st haris.d2.signpo.st conf/ tmp/
local_node=$1
remote_node=$2
conf_dir=$3
tmp_dir=$4
ns_ip=$5
ns_port=$6

# create tmp folder
dst_dir=$tmp_dir/$local_node/

if [ ! -e $dst_dir ]; then 
  echo "Missing folder $dst_dir"
  exit 1
fi

# sign the remote domain certificate
crypto-convert \
  -p $conf_dir/signpost.pem  \
  -d 30758400 \
  -s "C=UK,O=signpost,CN=$remote_node," \
  -i "C=UK,O=signpost,CN=$local_node," \
  -S $ns_ip \
  -P $ns_port \
  SIGN \
  $remote_node \
  DNS_PUB \
  $dst_dir/allowed-$remote_node.crt \
  PEM_CERT

cat $dst_dir/tmp.crt $dst_dir/allowed-*.crt > $dst_dir/ca.crt
chmod a+rw $dst_dir/ca.crt
