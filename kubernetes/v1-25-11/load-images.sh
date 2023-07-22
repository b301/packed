#!/bin/bash


images=$(ls ./exported-images)

for image in $images
do
    ctr -n k8s.io image import ./exported-images/$image
done
