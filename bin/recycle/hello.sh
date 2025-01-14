#!/bin/bash


    user=$(/run/current-system/sw/bin/whoami)       # Which user account to use for git commands -> $(/run/current-system/sw/bin/whoami)
    echo "hello ${user}" >> /home/temhr/hi.txt
