#!/bin/sh

sed -n -e "/wrong argument 'scheduling'/s/^.*: wrong argument/wrong argument/;/stop-after/p" compiler-output.raw
