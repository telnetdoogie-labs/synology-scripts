#!/bin/bash

TARGET=/volume1/Media/

# Finding
echo 'Will Remove..'
find "$TARGET" -name '.DS_Store' -type f
find "$TARGET" -name '._*' -type f -size -10k
find "$TARGET" -name '.AppleDouble' -type d -prune
# Deleting
echo 'Deleting...'
find "$TARGET" -name '.DS_Store' -type f -delete
find "$TARGET" -name '._*' -type f -size -10k -delete
# .AppleDouble folders usually contain files, and `find -delete` only removes empty
# folders, so remove them recursively (-prune stops find descending into them first)
find "$TARGET" -name '.AppleDouble' -type d -prune -exec rm -rf {} +
# Done
echo 'Done'
