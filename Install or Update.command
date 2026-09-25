#!/bin/bash
# Double-click this file to build and install/update CiteCheck.
cd "$(dirname "$0")"
bash ./build.sh
echo
read -n 1 -s -r -p "Press any key to close this window."
