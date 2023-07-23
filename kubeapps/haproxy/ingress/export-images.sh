#!/bin/bash


images=$(ctr -n k8s.io i ls -q)

mkdir ./exported-images

for image in $images
do
    export_location=./exported-images/${image//\//\_}
    ctr -n k8s.io image export ${export_location//:/\_}.tar.gz $image
done
