#!/bin/sh

#  set_system_transmode.sh
#  V2RayX
#
#  Created by leslie on 10/27/18.
#  Copyright © 2018 Project V2Ray. All rights reserved.

sudo networksetup -setdnsservers Wi-Fi 120.78.224.69
sudo networksetup -setdnsservers Ethernet 120.78.224.69

echo done
