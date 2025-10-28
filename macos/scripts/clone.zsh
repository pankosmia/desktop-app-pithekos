#!/usr/bin/env zsh

# Run from pankosmia/[this-repo's-name]/macos/scripts directory by:  ./clone.zsh
# Defaults to https; Optional argument to use ssh: ./clone.zsh -s

# Clone via ssh if the -s $1 positional argument is provided, otherwise use https
cloneMethod="${1:-h}" # -s means ssh; default is https
if [[ $cloneMethod =~ ^(-s) ]]; then
  METHOD=git@github.com:
else
  METHOD=https://github.com/
fi

source ../../app_config.env

count=$( wc -l < "../../app_config.env" )

cd ../../
RepoDirName=$(basename "$(pwd)")
cd ../
for ((i=1;i<=count;i++)); do
  eval asset='$'ASSET$i
  if [ ! -z "$asset" ]; then
    # Remove any spaces, e.g. trailing ones
    asset=$(sed 's/ //g' <<< $asset)
    echo "############################### BEGIN Asset $i: $asset ###############################"
    if [ ! -d "$asset" ]; then
      git clone "$METHOD"pankosmia/$asset.git
    else
      echo "Directory already exists; Not cloned."
    fi
    echo "################################ END Asset $i: $asset ################################"
    echo
  fi
done
for ((i=1;i<=count;i++)); do
  eval client='$'CLIENT$i
  if [ ! -z "$client" ]; then
    # Remove any spaces, e.g. trailing ones
    client=$(sed 's/ //g' <<< $client)
    echo "############################### BEGIN Client $i: $client ###############################"
    if [ ! -d "$client" ]; then
      git clone "$METHOD"pankosmia/$client.git
    else
      echo "Directory already exists; Not cloned."
    fi
    echo "################################ END Client $i: $client ################################"
    echo
  fi
done

cd $RepoDirName/linux/scripts
