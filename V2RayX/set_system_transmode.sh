#!/bin/sh

#  set_system_transmode.sh
#  V2RayX
#
#  Created by leslie on 10/27/18.
#  Copyright © 2018 Project V2Ray. All rights reserved.

sudo networksetup -setdnsservers Wi-Fi 8.8.8.8
sudo networksetup -setdnsservers Ethernet 8.8.8.8

echo done
