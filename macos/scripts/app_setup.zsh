#!/usr/bin/env zsh

echo
echo "     ****************************************************"
echo "     * This script uses /app_config.env                 *"
echo "     * to generate/rebuild/replace:                     *"
echo "     *   - /windows/buildResources/setup/app_setup.json *"
echo "     *   - /macos/buildResources/setup/app_setup.json   *"
echo "     *   - /linux/buildResources/setup/app_setup.json   *"
echo "     *   - /buildSpec.json                              *"
echo "     *   - /globalBuildResources/i18nPatch.json         *"
echo "     *   - /globalBuildResources/product.json           *"
echo "     ****************************************************"
echo

source ../../app_config.env

clients="../buildResources/setup/app_setup.json"
spec="../../buildSpec.json"
name="../../globalBuildResources/i18nPatch.json"
product="../../globalBuildResources/product.json"

echo "{"> $name
echo "  \"branding\": {">> $name
echo "    \"software\": {">> $name
echo "      \"name\": {">> $name
echo "        \"en\": \"$APP_NAME\"">> $name
echo "      }">> $name
echo "    }">> $name
echo "  }">> $name
echo "}">> $name

echo "{"> $spec
echo "  \"app\": {">> $spec
echo "    \"name\": \"$APP_NAME\",">> $spec
echo "    \"version\": \"$APP_VERSION\"">> $spec
echo "  },">> $spec

echo "  \"bin\": {">> $spec
echo "    \"src\": \"../../local_server/target/release/local_server\"">> $spec
echo "  },">> $spec

echo "  \"lib\": [">> $spec
count=$( wc -l < "../../app_config.env" )
for ((i=1;i<=count;i++)); do
  eval asset='$'ASSET$i
  if [ ! -z "$asset" ]; then
    # Remove any spaces, e.g. trailing ones
    asset=$(sed 's/ //g' <<< $asset)
    echo "    {">> $spec
    src="      \"src\": \"../../../$asset"
  fi
  eval asset_path='$'ASSET$i'_PATH'
  if [ ! -z "$asset_path" ]; then
    # Remove any spaces, e.g. trailing ones
    asset_path=$(sed 's/ //g' <<< $asset_path)
    src=$src$asset_path"\","
    echo "$src">> $spec
  fi
  eval asset_name='$'ASSET$i'_NAME'
  if [ ! -z "$asset_name" ]; then
    # Remove any spaces, e.g. trailing ones
    asset_name=$(sed 's/ //g' <<< $asset_name)
    echo "      \"targetName\": \"$asset_name\"">> $spec
    echo "    },">> $spec
  fi
done

echo "    {">> $spec
echo "      \"src\": \"../buildResources/setup\",">> $spec
echo "      \"targetName\": \"setup\"">> $spec
echo "    }">> $spec
echo "   ],">> $spec

echo "  \"libClients\": [">> $spec
echo "{"> $clients
echo "  \"clients\": [">> $clients

# Get total number of clients
clientcount=0
for ((i=1;i<=count;i++)); do
  eval client='$'CLIENT$i
  if [ ! -z "$client" ]; then
    ((clientcount=clientcount+1))
  fi
done
for ((i=1;i<=count;i++)); do
  eval client='$'CLIENT$i
  if [ ! -z "$client" ]; then
    # Remove any spaces, e.g. trailing ones
    client=$(sed 's/ //g' <<< $client)
    echo "    {">> $clients
    echo "      \"path\": \"%%PANKOSMIADIR%%/$client\"">> $clients
    if [ $i -eq $clientcount ]; then
      echo "    \"../../../$client\"">> $spec
      echo "    }">> $clients
    else
      echo "    \"../../../$client\",">> $spec
      echo "    },">> $clients
    fi
  fi
done
echo "  ]">> $clients
echo "}">> $clients

echo "{"> $product
echo "  \"name\": \"$APP_NAME\",">> $product
echo "  \"short_name\": \"$APP_SHORT_NAME\",">> $product
echo "  \"version\": \"$APP_VERSION\",">> $product
echo "  \"datetime\": \"$(date '+%d %b %Y %H:%M:%S UTC%:z')\"">> $product
echo "}">> $product

echo "  ],">> $spec
echo "  \"favIcon\": \"../../globalBuildResources/favicon.ico\",">> $spec
echo "  \"theme\": \"../../globalBuildResources/theme.json\",">> $spec
echo "  \"product\": \"../../globalBuildResources/product.json\"">> $spec
echo "}">> $spec

echo
echo "/buildSpec.json generated/rebuilt/replaced"
echo "/globalBuildResources/i18nPatch.json generated/rebuilt/replaced"
echo "/globalBuildResources/product.json generated/rebuilt/replaced"
echo "/macos/buildResources/setup/app_setup.json generated/rebuilt/replaced"
echo
echo "Copying /macos/buildResources/setup/app_setup.json to /windows/buildResources/setup/"
cp ../buildResources/setup/app_setup.json ../../windows/buildResources/setup/app_setup.json
echo "Copying /macos/buildResources/setup/app_setup.json to /linux/buildResources/setup/"
cp ../buildResources/setup/app_setup.json ../../linux/buildResources/setup/app_setup.json

