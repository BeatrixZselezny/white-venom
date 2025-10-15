#!/bin/bash
# It's a script give mitingation for
# hardware to hardware vunerabilityes for Debian.
# Usable just with grub-editenv, you never try
# edit this whit hand!
# Never don't use without experience as it may
# cause performance!
# Can you learn more about that in here: https://docs.kernel.org/admin-guide/hw-vuln/index.html
# Author: Beatrix Zelezny 2025.
###


cd /sys/devices/system/cpu/vulnerabilities/

grub-editenv - set "$(grub-editenv - list | grep kernelopts) l1tf=full,force"
grub-editenv - set "$(grub-editenv - list | grep kernelopts) smt=full,nosmt"
grub-editenv - set "$(grub-editenv - list | grep kernelopts) spectre_v2=on"
grub-editenv - set "$(grub-editenv - list | grep kernelopts) spec_store_bypass_disable=seccomp"
grub-editenv - set "$(grub-editenv - list | grep kernelopts) slab_nomerge=yes"
grub-editenv - set "$(grub-editenv - list | grep kernelopts) mce=0"
grub-editenv - set "$(grub-editenv - list | grep kernelopts) pti=on"
