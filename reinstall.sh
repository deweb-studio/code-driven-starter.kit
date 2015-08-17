#!/bin/bash

#script for syncing stage server with Prod site.

###################
#     Actions     #
###################

#declare function to run reinstal job
run_reinstal_job () {
    if [[ -z ${1+x} || -z ${2+x} || -z ${3+x} || -z ${4+x} || -z ${5+x} || -z ${6+x} ]]; then
        echo "Error! Invalid paremeters received. Can't do this job.";
        exit 1;
    fi

    #Find current path
    CURRENT_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

    #defining required variables
    PATH_TO_BM_MANUAL=$1
    PATH_TO_SYNC_FOLDER=$2
    PATH_TO_DOCROOT=$3
    REMOTE_USER=$4
    REMOTE_SERVER=$5
    REMOTE_PORT=$6

    #run sql dumb on remote (via Backup and Migrate module)
    echo "Current job: run 'drush bam-backup' on the server $REMOTE_SERVER in folder $PATH_TO_DOCROOT."
    ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_SERVER "cd $PATH_TO_DOCROOT; drush bam-backup"

    #run rsync on local machine (sync sites/default/files/ folder)
    echo "Current job: sync files folder with remote"
    SSH_OPT="ssh -p $REMOTE_PORT"
    CURRENT_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    mkdir $CURRENT_PATH/public_html/$PATH_TO_SYNC_FOLDER
    rsync -avh --delete -e "$SSH_OPT" $REMOTE_USER@$REMOTE_SERVER:$PATH_TO_DOCROOT/$PATH_TO_SYNC_FOLDER/ $CURRENT_PATH/public_html/$PATH_TO_BM_MANUAL

    #cd ro site root
    cd "$CURRENT_PATH"/public_html

    #drop current db
    echo "Current job: drop local DB"
    drush sql-drop -y

    #Restore database from latest dump
    BASE_DUMP=$(ls -t $PATH_TO_BM_MANUAL/*.mysql.gz | head -1)

    echo "Current job: restoring local DB from dump $BASE_DUMP"
    gunzip < $BASE_DUMP | drush sql-cli

    echo "Done! Servers was synchronized"
}

#Find current path
CURRENT_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#include file with settings
. "$CURRENT_PATH"/settings.sh

CURRENT_USER=$(whoami)

if [ "$CURRENT_USER" = "vagrant" ]; then
    echo "This is DEV. Run DEV-STAGE sync..."

    #create file settings.php from local.settings.php if it doesn't exist
    if [ ! -f $CURRENT_PATH/public_html/sites/default/settings.php ]; then
        if cp $CURRENT_PATH/files/local.settings.php $CURRENT_PATH/public_html/sites/default/settings.php; then
            echo "Settings file created!"
        else
            echo "Error can't create file settings.php!\n You should set at least chmod 755 on sites/default folder."
            exit 1;
        fi
    fi

    PATH_TO_SYNC_FOLDER = $PATH_TO_BM_MANUAL
    run_reinstal_job $PATH_TO_BM_MANUAL $PATH_TO_SYNC_FOLDER $STAGE_PATH_TO_DOCROOT $STAGE_REMOTE_USER $STAGE_REMOTE_SERVER $STAGE_REMOTE_PORT

    # we need to ensure that stage_file_proxy module is downloaded and enabled
    # since it always disabled on STAGE-server
    cd "$CURRENT_PATH"/public_html
    drush pm-download stage_file_proxy -n
    drush pm-enable --yes stage_file_proxy
    drush variable-set stage_file_proxy_origin "$STAGE_SITE_ADRESS"

elif [ "$CURRENT_USER" = "$STAGE_REMOTE_USER" ]; then
    echo "This is STAGE. Run STAGE-PROD sync..."

    PATH_TO_SYNC_FOLDER = "sites/default/files"
    run_reinstal_job $PATH_TO_BM_MANUAL $PATH_TO_SYNC_FOLDER $PROD_PATH_TO_DOCROOT $PROD_REMOTE_USER $PROD_REMOTE_SERVER $PROD_REMOTE_PORT

else
    echo "Cant run on this machine. Username doesn't match!"
    exit 1;
fi
