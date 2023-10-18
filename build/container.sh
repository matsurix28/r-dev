#!/bin/bash

R -e "install.packages('renv', lib='/home/docker/library'); .libPaths('/home/docker/library'); renv::init()"
sed -i "s/bash \/home\/docker\/workspace\/build\/container.sh/R -e \"renv::restore()\"; bash/g" /home/docker/workspace/build/Dockerfile
rm /home/docker/workspace/build/container.sh /home/docker/workspace/build/setup.sh
git init
exit
