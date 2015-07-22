#!/bin/bash
IPA=$1
REALM=$2
IPA_USER=keystone

source /home/functions.sh
remove_all $REALM $IPA $IPA_USER
