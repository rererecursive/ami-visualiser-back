#!/bin/bash
set -e

OHAI="ohai_tmp.log"

cp output.log $OHAI
sed -i '/---BEGIN_OHAI_OUTPUT---/,$!d' $OHAI
sed -i '/---END_OHAI_OUTPUT---/q' $OHAI
sed -i 's/%!(PACKER_COMMA)/,/g' $OHAI
sed '1,1d' $OHAI | sed '$d' | cut -d: -f2- > logs/ohai.json
rm $OHAI
