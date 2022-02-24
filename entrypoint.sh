#!/bin/sh -l

#set -e at the top of your script will make the script exit with an error whenever an error occurs (and is not explicitly handled)
set -eu

TSTAMP=$(date -I)
TEMP_SFTP_FILE="../sftp"
ARCHIVE_FILE="../archive-$TSTAMP.tar.gz"

if test $8 = "true"; then
  echo "Connection via sftp protocol only, skip the command to create a directory"
else
  echo 'Connecting to SSH server and creating directory..'
  sshpass -p "$4" ssh -o StrictHostKeyChecking=no -p $3 $1@$2 mkdir -p $6
  echo 'Connection to SSH server and directory creation finished successfully!'
fi

echo 'Starting file transfer..'
if test $10 = "true"; then
    echo 'Starting compression...'
    tar -czvf $ARCHIVE_FILE $5
    echo 'Finishing compression...'
# Formatting can't be resolved, feel free to PR if I am wrong.
sshpass -p $4 sftp -P $3 $7 -o StrictHostKeyChecking=no $1@$2 <<-EOF
put -r $ARCHIVE_FILE $6
EOF
elif test $11 = "true"; then
    echo "Syncing files using LFTP mirror mode"
    # Use lftp to mirror files
    lftp -e "set sftp:auto-confirm 1; mirror -R -x .git -x .github $7 $5 $6; quit" -u $1 --password "$4" sftp://$2
else
    echo "Syncing files using batched SFTP"
    # create a temporary file containing sftp commands
    touch $TEMP_SFTP_FILE
    if [ -d "$5" ]
    then
    printf "%s\n" "-mkdir $6" >$TEMP_SFTP_FILE
    (cd $5; find * -type d -exec echo -mkdir $6/{} \;) >>$TEMP_SFTP_FILE
    printf "%s" "put -r $5* $6" >>$TEMP_SFTP_FILE
    else
    printf "%s" "put $5 $6" >>$TEMP_SFTP_FILE
    fi
    #-o StrictHostKeyChecking=no to avoid "Host key verification failed".
    sshpass -p "$4" sftp -oBatchMode=no -b $TEMP_SFTP_FILE -P $3 $7 -o StrictHostKeyChecking=no $1@$2
fi

echo 'File transfer finished successfully!'

if [ -z "$9" ]
then
    echo 'No SSH command specified, success!'
else
    echo 'SSH command being ran...'
    sshpass -p $4 ssh -o StrictHostKeyChecking=no $1@$2 -p $3 "cd $6;$9"
    echo 'SSH command completed!'
fi

exit 0
