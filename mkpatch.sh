#!/usr/local/bin/bash -e
cd mesa
git pull origin main || exit
git format-patch -1 || exit
mv *.patch ../ || exit
