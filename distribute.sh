#! /bin/sh

SRC_NAME=id-utils-4.0

gpg -b --yes $SRC_NAME.tar.gz

echo "directory: id-utils" > $SRC_NAME.tar.gz.directive

gpg --clearsign --yes $SRC_NAME.tar.gz.directive

#upload results to ftp.
cmdftp ftp-upload.gnu.org<<EOF
cd /incoming/ftp
u $SRC_NAME.tar.gz .
u $SRC_NAME.tar.gz.sig .
u $SRC_NAME.tar.gz.directive.asc .
exit
EOF