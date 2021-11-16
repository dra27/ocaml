#!/bin/sh
exec > "${ocamltest_response}" 2>&1
LD="$(ld -v 2>&1 | grep 'ld64-[0-9]*\.')"
LDVER="${LD#*ld64-}"
LDVER="${LDVER%.*}"
if [ -z "$LD" ]; then
  echo "unknown linker: pattern ld64-[0-9]*\. not found in 'ld -v' output"
  test_result=${TEST_SKIP}
elif [ "$LDVER" -lt 224 ]; then
  echo "ld version is $LDVER, only 224 or above are supported"
  test_result=${TEST_SKIP}
else
  test_result=${TEST_PASS}
fi

exit "${test_result}"
