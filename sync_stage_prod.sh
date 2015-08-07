#!/bin/bash

#script for syncing stage server with Prod site.

####################
# Settings section #
####################

#host ip - the result of `hostname -i` on stage server 
#(script will run only on machine with this ip adress)
#example: 111.111.111.111
HOST_IP=""

#absolute path to site root on prod-server (without last /)
#example: /home/prod/public_html
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

#run sql dumb on remote (via Backup and Migrate module)
echo "Current job: run 'drush bam-backup' on the server $REMOTE_SERVER in folder $PATH_TO_SITEROOT."
ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_SERVER "cd $PATH_TO_SITEROOT; drush bam-backup"

#run rsync on local machine (sync sites/default/files/ folder)
echo "Current job: sync files folder with remote"
SSH_OPT="ssh -p $REMOTE_PORT"
CURRENT_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
rsync -avh --delete -e "$SSH_OPT" $REMOTE_USER@$REMOTE_SERVER:$PATH_TO_SITEROOT/sites/default/files/ $CURRENT_PATH/sites/default/files

#drop current db
echo "Current job: drop local DB"
drush sql-drop -y

#Restore database from latest dump
BASE_DUMP=$(ls -t $PATH_TO_BM_MANUAL/*.mysql.gz | head -1)

echo "Current job: restoring local DB from dump $BASE_DUMP"
gunzip < $BASE_DUMP | drush sql-cli

echo "Done! STAGE-server was synced with PROD-server"
