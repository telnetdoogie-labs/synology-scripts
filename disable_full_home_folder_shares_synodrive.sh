#!/bin/bash

# from https://www.synoforum.com/threads/synology-drive-howto-revert-home-folder-sync-back-to-drive-subfolder-sync.12618/
#
#
#
sudo sqlite3 /volume1/@synologydrive/@sync/syncfolder-db.sqlite "update config_table SET value='0' WHERE key='index_home_config'" ".exit"
