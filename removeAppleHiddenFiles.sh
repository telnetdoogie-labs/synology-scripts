#!/bin/bash


# Finding
echo 'Will Remove..'
find /volume1/Media/ -name '.DS_Store' -type f
find /volume1/Media/ -name '._*' -type f -size -10k
find /volume1/Media/ -name '.AppleDouble' -type d
# Deleting
echo 'Deleting...'
find /volume1/Media/ -name '.DS_Store' -type f -delete
find /volume1/Media/ -name '._*' -type f -size -10k -delete
find /volume1/Media/ -name '.AppleDouble' -type d -delete
# Done
echo 'Done'
