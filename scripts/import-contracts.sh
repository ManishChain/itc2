#!/bin/bash

ENV_FILE=.env
if test -f "$ENV_FILE"; then
    source $ENV_FILE
fi

JWTTOKEN=`curl -X POST $DEMO_ENTETH_MIDDLEWARE/dapi/v1/authentication/username-password -H "Content-Type: application/json" -d "{ \"password\": \"$MIDDLEWARE_PASSWORD\", \"username\": \"$MIDDLEWARE_USERNAME\"}" --silent | jq -r ".jwtToken"`

CURLFILES=""
for contract in $(find $(pwd)/build/contracts/ -name '*.json')
 do CURLFILES="$CURLFILES -F file=@$contract"
done
 
curl $DEMO_ENTETH_MIDDLEWARE/dapi/v1/contracts/import -H 'accept: application/json' -H "Authorization: ${JWTTOKEN}" ${CURLFILES}

echo
echo