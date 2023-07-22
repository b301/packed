#!/bin/bash


images=$(cat required-images.txt)


for image in $images
do
    ctr -n k8s.io i pull $image
done
