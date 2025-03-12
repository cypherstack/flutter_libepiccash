#!/bin/bash

if curl --retry 20 --retry-delay 2 --retry-connrefused rabbit:15672 ; then
    ./epicbox
else
    echo "goodbye!"
fi
