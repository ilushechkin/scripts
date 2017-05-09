#!/bin/bash
#
PREFIX=`hostname`
FNAME="full_*"
GPGIN="/u01/backup/gpgin/"
GPGOUT="/u01/backup/gpgout/"
GPGKEYFILE="AABBCCDD_scret.gpg"
GPGPASSPHRASE="password"
#

echo "Started on $PREFIX at `date`"
echo "Source directory: $GPGIN"
echo "Destination directory: $GPGOUT"

# Verify that the destination folder exists
if [ ! -d "$GPGOUT" ]; then
    echo "$PREFIX Destination folder \"$GPGOUT\" not found. Exiting..."
    exit 1
fi

# GPG Import Secret Key
gpg --import $GPGKEYFILE

# GPG Decrypt async function
gpg_decrypt(){
    local gpgfile=$1
    gpg --batch --passphrase $GPGPASSPHRASE --output $GPGOUT${gpgfile%.*} --decrypt $GPGIN$gpgfile
    # rm -f $GPGIN$gpgfile
}

# Proceed encrypted files
find $GPGIN -type f -name $FNAME -print0 | while IFS= read -r -d $'\0' line; do
    echo "$(date +%T) ${line##*/}"
    gpg_decrypt ${line##*/} &
done

# Wait for all decrypt jobs
wait

echo "$(date +%T) Done!"
echo "Finished at `date`"