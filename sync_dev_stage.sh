#!/bin/bash

#script for syncing dev environments with stage.


####################
# Settings section #
####################

#host ip - the ip was defined in vagrant_ip variable in config.yml file
#example: 111.111.111.111
HOST_IP=""

#absolute path to site root on stage-server (without last /)
#example: /home/stage/public_html
PATH_TO_SITEROOT=""

#other remote host parameters
#will connect like: ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_SERVER
REMOTE_USER=""
REMOTE_SERVER=""
REMOTE_PORT="22"

#path to backup and migrate manual backups folder 
#e.g sites/default/files/private/backup_migrate/manual
PATH_TO_BM_MANUAL="sites/default/files/private/backup_migrate/manual"

###################
#     Actions     #
###################

CURRENT_HOST_IP=$(hostname -i)

if [ "$HOST_IP" != "$CURRENT_HOST_IP" ]; then
  echo "Cant run on this machine. Wrong host IP!"
  exit 1;
fi

CURRENT_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#create file settings.php from local.settings.php if it doesn't exist
if [ ! -f $CURRENT_PATH/sites/default/settings.php ]; then
    cp $CURRENT_PATH/sites/default/local.settings.php $CURRENT_PATH/sites/default/settings.php
    echo "Settings file created!"
fi


#run sql dumb on remote (via Backup and Migrate module)
echo "Current job: run 'drush bam-backup' on the server $REMOTE_SERVER in folder $PATH_TO_SITEROOT."
ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_SERVER "cd $PATH_TO_SITEROOT; drush bam-backup"

#run rsync on local machine (sync sites/default/files/ folder)
echo "Current job: sync files folder with remote"
SSH_OPT="ssh -p $REMOTE_PORT"
rsync -avh --delete -e "$SSH_OPT" $REMOTE_USER@$REMOTE_SERVER:$PATH_TO_SITEROOT/sites/default/files/ $CURRENT_PATH/sites/default/files

#drop current db
echo "Current job: drop local DB"
drush sql-drop

#Restore database from latest dump
BASE_DUMP=$(ls -t $PATH_TO_BM_MANUAL/*.mysql.gz | head -1)

echo "Current job: restoring local DB from dump $BASE_DUMP"
gunzip < $BASE_DUMP | drush sql-cli

echo "Done! DEV-server was synced with STAGE-server"