#!/bin/bash

USER_ID=$(id -u)
GROUP_ID=$(id -g)

# For Rootless Docker
if [ -n "$(docker info 2>&1 | grep 'rootless')" ]; then
  ROOTLESS=true
  # Add rootless-docker group
  SUBGID=`grep "^${USER}:" /etc/subgid | grep -oE ":[0-9]+:" | sed "s/://g"`
  CONTAINER_GID=$(( $SUBGID + $USER_ID - 1 ))
  
  # Check group already exists
  if [ -z "$(grep -E "^[^:]+:[^:]+:$CONTAINER_GID:" /etc/group)" ]; then
    echo "Create Rootless-docker group"
    GNAME=rootless-$USER
    sudo groupadd -g $CONTAINER_GID $GNAME
  else
    GNAME=`grep -E "^[^:]+:[^:]+:$CONTAINER_GID:" /etc/group | grep -oE "^[^:]+"`
  fi
  if [ -z "$(id -G | grep $CONTAINER_GID)" ]; then
    echo "Add Rootless-docker group to use docker bind mount."
    sudo gpasswd -a $USER $GNAME
  fi
else
  ROOTLESS=false
fi

ROOT=$(cd $(dirname $0)/..; pwd)
PARENT=$(cd $(dirname $0)/../..; pwd)

# Set R version
FIRST=true
read -p "Enter R vsersion (default: latest): " R_VER

while true; do
  if ! "$FIRST"; then
    echo "Error, couldn't pull r-base:$R_VER. "
    read -p "Retype R version: " R_VER
  fi
  FIRST=false
  if [[ "$R_VER" == "" ]]; then
    R_VER="latest"
  fi
  docker pull r-base:$R_VER && break
done

# Set Project name
read -p "Enter Project Name: " ProjName
while [[ ! $ProjName =~ ^[a-zA-Z0-9]+([a-zA-Z0-9]|-|_)*[a-zA-Z0-9]+$ ]] || [[ $ProjName =~ .*(-_|_-).* ]]; do
  echo "$ProjName: Invalid reference format. Only '-' or '_' is allowed."
  read -p "Retype Project Name: " ProjName
done

while true; do
  # Check directory
  while [ -e $PARENT/${ProjName} ]; do
    echo "Directory $ProjName already exists."
    read -p "Enter New Project Name: " ProjName
  done

  # Check docker container
  CONTAINER=$(docker container ls -a -q -f name="^${ProjName,,}-r-[0-9]*$")
  if [ -n "$CONTAINER" ]; then
    echo "Container $ProjName already exists."
    read -p "Do you want to overwrite container? [y/N]: " yn
    case "$yn" in
      [yY]*) echo "Removing container..."
             docker stop $CONTAINER
             docker container rm $CONTAINER
             docker rmi ${ProjName,,}-r
             break;;
      *) read -p "Enter New Project Name: " ProjName;;
    esac
  else
    break
  fi
done

ProjDir=$PARENT/$ProjName
cp -r $ROOT $ProjDir
rm -rf $ProjDir/.git $ProjDir/README.md
mv $ProjDir/build/README.md $ProjDir/
sed -i "s/FROM r-base.*$/FROM r-base:$R_VER/" $ProjDir/build/Dockerfile


# Generate .env file
echo "Setting UID, GID and Project name."
echo "UID=$USER_ID" > $ProjDir/.env
echo "GID=$GROUP_ID" >> $ProjDir/.env
echo "COMPOSE_PROJECT_NAME=${ProjName,,}" >> $ProjDir/.env

# Initial setting
if [ -z "$(docker volume ls -q -f name='renv')" ]; then
  echo "Create renv volume."
  docker volume create renv
fi


# Start docker container
cd $ProjDir
echo "Compose up."
echo "Initializing renv..."
docker compose up
docker container rm ${ProjName,,}-r-1
docker rmi ${ProjName,,}-r
if "$ROOTLESS"; then
  sudo chmod -R g+w $ProjDir
fi
git config --global --add safe.directory $ProjDir
echo "Setup is complete. Please restart shell to reflect groupadd."
