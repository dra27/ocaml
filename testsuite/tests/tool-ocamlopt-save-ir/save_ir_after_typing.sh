#!/bin/sh

sed -n -e "/wrong argument 'typing'/s/^.*: wrong argument/wrong argument/;/save-ir-after/p" compiler-output.raw
