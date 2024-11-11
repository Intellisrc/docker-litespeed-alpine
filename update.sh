#!/bin/bash
rep=$(basename $(dirname $(realpath $0)))
ver=$(grep "FROM" ./Dockerfile | awk -F':' '{ print $2 }')
if [[ $ver == "" ]]; then
	echo "Version not found"
	exit
fi
echo "VERSION: $ver"
docker build -t $rep .
docker tag $rep:latest intellisrc/$rep:$ver
if docker push intellisrc/$rep:$ver; then
	echo "Published : intellisrc/$rep:$ver"
fi
