#!/bin/bash

PM_FILE='Koha/Plugin/Fi/KohaSuomi/DI.pm'
DATE=`date +"%Y-%m-%d"`
VERSION=`git log -1 --pretty=oneline --decorate | egrep -o "tag: v[0-9.]+" | sed -e "s/tag: v//"`
RELEASE_FILE="koha-plugin-rest-di-${VERSION}.kpz"
if [ ! -z "$VERSION" ]
then
  echo "Building release package ${RELEASE_FILE}"
  if [ -e ${RELEASE_FILE} ]
  then
    rm ${RELEASE_FILE}
  fi
  mkdir dist
  cp -r Koha dist/.
  sed -i -e "s/{VERSION}/${VERSION}/g" "dist/${PM_FILE}"
  sed -i -e "s/1900-01-01/${DATE}/g" "dist/${PM_FILE}"
  cd dist
  zip -r ../${RELEASE_FILE} ./Koha
  cd ..
  rm -rf dist
else
  echo "No version tag found"
fi
