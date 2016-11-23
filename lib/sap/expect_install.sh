#!/bin/bash
if ! expect </dev/null >/dev/null 2>&1; then
    if ! $YUM install expect >/dev/null 2>&1;then
        exit 1
    fi
fi