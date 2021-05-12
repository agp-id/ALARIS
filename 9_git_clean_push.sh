#!/bin/sh
# hapus folder .git
rm -rf .git

#
git init
git add .
echo '_______________________'
echo masukan pesan/commit:
read -e -p "" input
git commit -m "nganu: $input"
git branch -M main
git remote add origin git@github.com:agp-id/ALARIS.git
git push -f origin main
