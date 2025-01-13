#!/bin/bash


    user=$(/run/current-system/sw/bin/whoami)       # Which user account to use for git commands -> $(/run/current-system/sw/bin/whoami)
    echo "${user}" > /home/temhr/who.txt
    echo "hello" >> /home/temhr/hi.txt
