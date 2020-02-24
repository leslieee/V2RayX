#!/bin/sh

#  install_helper.sh
#  V2RayX
#
#  Copyright © 2016年 Cenmrev. All rights reserved.

cd `dirname "${BASH_SOURCE[0]}"`
sudo mkdir -p "/Library/Application Support/V2RayX/"
sudo cp v2rayx_sysconf "/Library/Application Support/V2RayX/"
sudo chown root:admin "/Library/Application Support/V2RayX/v2rayx_sysconf"
sudo chmod +s "/Library/Application Support/V2RayX/v2rayx_sysconf"

sudo cp tun2socks "/Library/Application Support/V2RayX/"
sudo chown root:admin "/Library/Application Support/V2RayX/tun2socks"
sudo chmod +s "/Library/Application Support/V2RayX/tun2socks"

sudo cp "/sbin/route" "/Library/Application Support/V2RayX/"
sudo chown root:admin "/Library/Application Support/V2RayX/route"
sudo chmod +s "/Library/Application Support/V2RayX/route"

sudo cp changedns "/Library/Application Support/V2RayX/"
sudo chown root:admin "/Library/Application Support/V2RayX/changedns"
sudo chmod +s "/Library/Application Support/V2RayX/changedns"

sudo cp changedns1 "/Library/Application Support/V2RayX/"
sudo chown root:admin "/Library/Application Support/V2RayX/changedns1"
sudo chmod +s "/Library/Application Support/V2RayX/changedns1"

echo done
