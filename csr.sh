#!/bin/bash

# be safe about permissions
LASTUMASK=`umask`
umask 077

# OpenSSL for HPUX needs a random file
RANDOMFILE=$HOME/.rnd

# create a config file for openssl
CONFIG=`mktemp -q /tmp/openssl-conf.XXXXXXXX`
if [ ! $? -eq 0 ]; then
    echo "Could not create temporary config file. exiting"
    exit 1
fi

echo "Private Key and Certificate Signing Request Generator"
echo

printf "FQDN/CommonName (i.e. www.google.com): "
read COMMONNAME
printf "Organization Unit (i.e. Ops): "
read ORGUNIT
printf "E-mail Address (i.e. emai@example.com) [optional]: "
read EMAILADDR
printf "What is your Organizations name (i.e. ACME): "
read ORG
echo "Type SubjectAltNames for the certificate, one per line. Enter a blank line to finish"
SAN=1   # bogus to begin loop
SANAMES="DNS:${COMMONNAME}"   # always include the CN
while [ ! "$SAN" = "" ]; do
    printf "SubjectAltName: DNS:"
    read SAN
    if [ "$SAN" = "" ]; then break; fi # end of input
    if [ "$SAN" = "$COMMONNAME" ]; then continue; fi # already added by default
    if [ "$SANAMES" = "" ]; then
        SANAMES="DNS:$SAN"
    else
        SANAMES="$SANAMES,DNS:$SAN"
    fi
done

# Replace '*' with "wild"
NAME=${COMMONNAME/#\*/wild}

# Config File Generation

cat <<EOF > $CONFIG
# -------------- BEGIN custom openssl.cnf -----
 HOME                    = $HOME
EOF

if [ "`uname -s`" = "HP-UX" ]; then
    echo " RANDFILE                = $RANDOMFILE" >> $CONFIG
fi

cat <<EOF >> $CONFIG
 oid_section             = new_oids
 [ new_oids ]
 [ req ]
 default_md              = sha1
 default_days            = 730            # how long to certify for
 default_keyfile         = ${NAME}.key
 distinguished_name      = req_distinguished_name
 encrypt_key             = no
 string_mask = nombstr
EOF

if [ ! "$SANAMES" = "" ]; then
    echo " req_extensions = v3_req # Extensions to add to certificate request" >> $CONFIG
fi

cat <<EOF >> $CONFIG
 [ req_distinguished_name ]
 countryName                     = Country Name (2 letter code)
 countryName_default             = US
 countryName_min                 = 2
 countryName_max                 = 2
 stateOrProvinceName             = State or Province Name (full name)
 stateOrProvinceName_default     = California
 localityName                    = Locality Name (eg, city)
 localityName_default            = San Francisco
 0.organizationName              = Organization Name (eg, company)
 0.organizationName_default      = $ORG
 organizationalUnitName          = Organizational Unit Name (eg, section)
 organizationalUnitName_default  = $ORGUNIT
 commonName                      = Common Name (eg, YOUR name)
 commonName_default              = $COMMONNAME
 commonName_max                  = 64
EOF
if [ ! "$EMAILADDR" = "" ]; then
cat <<EOF >> $CONFIG
 emailAddress                    = Email Address
 emailAddress_default            = $EMAILADDR
 emailAddress_max                = 40
EOF
fi
cat <<EOF >> $CONFIG
 [ v3_req ]
 nsCertType                      = server
 basicConstraints                = critical,CA:false
EOF

#if [ ! "$SANAMES" = "" ]; then
#    echo " subjectAltName=$SANAMES" >> $CONFIG
#fi

echo "# -------------- END custom openssl.cnf -----" >> $CONFIG

if [ ! -d ${NAME} ]; then
    mkdir ${NAME}
fi

cd ${NAME}

echo "Running OpenSSL..."
openssl req -batch -config $CONFIG -newkey rsa:2048 -out ${NAME}.csr

echo "Copy the following Certificate Request and paste into bug to obtain a Certificate."
echo "When you receive your certificate, you 'should' name it something like ${NAME}.crt"
echo
cat ${NAME}.csr
echo
echo The Certificate Signing Request is also available in ${NAME}.csr
echo The Private Key is stored in ${NAME}.key
echo

cd ..

rm $CONFIG

#restore umask
umask $LASTUMASK
