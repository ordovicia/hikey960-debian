#!/bin/bash

sudo sh -c 'test -f /etc/vagrant_provisioned && exit'

sudo sed -i'~' -E "s@http://(..\.)?(archive|security)\.ubuntu\.com/ubuntu@http://linux.yz.yamagata-u.ac.jp/pub/linux/ubuntu-archive/@g" /etc/apt/sources.list

sudo DEBIAN_FRONTEND=noninteractive apt -qq update
sudo DEBIAN_FRONTEND=noninteractive apt -qq install -y \
    bc make gcc-aarch64-linux-gnu \
    android-tools-fsutils \
    autoconf bison flex

sudo sh -c 'date > /etc/vagrant_provisioned'
