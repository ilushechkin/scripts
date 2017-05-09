#!/bin/bash
#
source /root/azure.variables.sh
#
PREFIX=`hostname`
INSTANCE="inst001"
GPGOUT="/u01/backup/"
GPGKEY="AABBCCDD"
ATDATE="$(date +%Y-%m-%d)"
MAIL="root@domain.com"
MAIL_BODY="/tmp/azure_mail_body"
MAIL_ATTACH="/tmp/azure_upload.txt"
MAIL_ATTACH2="/tmp/azure_list.txt"
#

#  Weekly or Monthly or even Yearly
if [ $(date +%d) -le 07 ] && [ $(date +%m) -eq 01 ]; then
   AZURE_STORAGE_PATH="annual_retention_5year"
elif [ $(date +%d) -le 07 ]; then
   AZURE_STORAGE_PATH="monthly_retention_1year"
else
   AZURE_STORAGE_PATH="weekly_retention_1month"
fi

echo "Started on $PREFIX at `date`" > $MAIL_BODY
echo "Upload logging started on $PREFIX at `date`" > $MAIL_ATTACH
echo "Source directory: $GPGOUT" >> $MAIL_BODY
echo "Destination storage account: $AZURE_STORAGE_ACCOUNT" >> $MAIL_BODY
echo "Destination prefix: $PREFIX/$INSTANCE/$AZURE_STORAGE_PATH/$ATDATE" >> $MAIL_BODY

# Verify that the destination folder exists
if [ ! -d "$GPGOUT" ]; then
    echo "$PREFIX Destination folder \"$GPGOUT\" not found. Exiting..."
    exit 1
fi

# Azure upload async function
azure_upload(){
    local gpgfile=$1
    echo "$(date +%T) $gpgfile" >> $MAIL_BODY
    /root/bin/az storage blob upload -f $GPGOUT$gpgfile -c $AZURE_STORAGE_CONTAINER -n "$PREFIX/$INSTANCE/$AZURE_STORAGE_PATH/$ATDATE - $gpgfile" >> $MAIL_ATTACH
    sleep 10
    rm -f $GPGOUT$gpgfile
}

# Proceed folders
mv ${GPGOUT}oracle_home.tar.gz ${GPGOUT}oracle_home.tar.gz.old
tar -czp --exclude="/home/oracle/test" -f ${GPGOUT}oracle_home.tar.gz ~oracle/
gpg --output ${GPGOUT}oracle_home.tar.gz.gpg --recipient $GPGKEY --encrypt ${GPGOUT}oracle_home.tar.gz
azure_upload oracle_home.tar.gz.gpg &

mv ${GPGOUT}root_home.tar.gz ${GPGOUT}root_home.tar.gz.old
tar -czpf ${GPGOUT}root_home.tar.gz ~/
gpg --output ${GPGOUT}root_home.tar.gz.gpg --recipient $GPGKEY --encrypt ${GPGOUT}root_home.tar.gz
azure_upload root_home.tar.gz.gpg &

mv ${GPGOUT}etc_files.tar.gz ${GPGOUT}etc_files.tar.gz.old
tar -czpf ${GPGOUT}etc_files.tar.gz /etc/passwd /etc/group /etc/shadow
gpg --output ${GPGOUT}etc_files.tar.gz.gpg --recipient $GPGKEY --encrypt ${GPGOUT}etc_files.tar.gz
azure_upload etc_files.tar.gz.gpg &

# Wait for all upload jobs
wait
sleep 60

echo "$(date +%T) Done!" >> $MAIL_BODY
/root/bin/az storage blob list -c $AZURE_STORAGE_CONTAINER -o table | grep $PREFIX > $MAIL_ATTACH2
echo "Total files uploaded -> $(cat $MAIL_ATTACH2 | grep 'tar.gz.gpg' | grep $ATDATE' - ' | wc -l)" >> $MAIL_BODY
echo "Finished at `date`" >> $MAIL_BODY

cat $MAIL_BODY | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | mail -r ${PREFIX}@domain.com -s "Folders on $PREFIX archived to cold storage" -a $MAIL_ATTACH -a $MAIL_ATTACH2 "$MAIL"