#!/bin/bash
# Please edit the variables below to suit your installation
# Note: for an installation created by the Alfresco installer, you only need to edit ALFRESCO_HOME

while [[ $# > 0 ]]
do
key="$1"
case $key in
    --alf-home)
    ALFRESCO_HOME="$2"
    shift # past argument
    ;;
    --keystore-home)
    ALFRESCO_KEYSTORE_HOME="$2"
    shift # past argument
    ;;
    --solr-home)
    SOLR_HOME="$2"
    #shift # past argument
    ;;
    --java-home)
    JAVA_HOME="$2"
    shift # past argument
    ;;
    --store-type)
    STORE_TYPE="$2"
    shift # past argument
    ;;
    --help)
    echo "usage keytool.sh --alf-home <path> --keystore-home <path> --solr-home <path> --java-home <path> --store-type <JCEKS|JKS>"
    echo "keytool.sh --help prints this help"
    exit 0
    ;;
esac
shift # past argument or value
done

CERTIFICATE_HOME=`mktemp -d`

echo ALFRESCO_HOME="$ALFRESCO_HOME"
echo ALFRESCO_KEYSTORE_HOME="$ALFRESCO_KEYSTORE_HOME"
echo SOLR_HOME="$SOLR_HOME"
echo JAVA_HOME="$JAVA_HOME"
echo CERTIFICATE_HOME="$CERTIFICATE_HOME"
echo STORE_TYPE="$STORE_TYPE"

# The directory containing the alfresco keystores, as referenced by keystoreFile and truststoreFile attributes in tomcat/conf/server.xml
#ALFRESCO_KEYSTORE_HOME=$ALFRESCO_HOME/alf_data/keystore

# SOLR installation directory

# Java installation directory
# Location in which new keystore files will be generated
# The repository server certificate subject name, as specified in tomcat/conf/tomcat-users.xml with roles="repository"
REPO_CERT_DNAME="CN=Alfresco Repository, OU=Unknown, O=Alfresco Software Ltd., L=Maidenhead, ST=UK, C=GB"

# The SOLR client certificate subject name, as specified in tomcat/conf/tomcat-users.xml with roles="repoclient"
SOLR_CLIENT_CERT_DNAME="CN=Alfresco Repository Client, OU=Unknown, O=Alfresco Software Ltd., L=Maidenhead, ST=UK, C=GB"

# The number of days before the certificate expires
CERTIFICATE_VALIDITY=36525

# Ensure certificate output dir exists
#mkdir -p "$CERTIFICATE_HOME"
#mkdir -p "$ALFRESCO_HOME"
#mkdir -p "$ALFRESCO_KEYSTORE_HOME"
#mkdir -p "$SOLR_HOME"

# Remove old output files (note they are backed up elsewhere)
 if [ -f "$CERTIFICATE_HOME/ssl.keystore" ]; then rm "$CERTIFICATE_HOME/ssl.keystore"; fi
 if [ -f "$CERTIFICATE_HOME/ssl.truststore" ]; then rm "$CERTIFICATE_HOME/ssl.truststore"; fi
 if [ -f "$CERTIFICATE_HOME/browser.p12" ]; then rm "$CERTIFICATE_HOME/browser.p12"; fi
 if [ -f "$CERTIFICATE_HOME/ssl.repo.client.keystore" ]; then rm "$CERTIFICATE_HOME/ssl.repo.client.keystore"; fi
 if [ -f "$CERTIFICATE_HOME/ssl.repo.client.truststore" ]; then rm "$CERTIFICATE_HOME/ssl.repo.client.truststore"; fi

# Generate new self-signed certificates for the repository and solr
"$JAVA_HOME/bin/keytool" -genkeypair -keyalg RSA -dname "$REPO_CERT_DNAME" -validity $CERTIFICATE_VALIDITY -alias ssl.repo -keypass kT9X6oe68t -keystore "$CERTIFICATE_HOME/ssl.keystore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
"$JAVA_HOME/bin/keytool" -exportcert -alias ssl.repo -file "$CERTIFICATE_HOME/ssl.repo.crt" -keystore "$CERTIFICATE_HOME/ssl.keystore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
"$JAVA_HOME/bin/keytool" -genkeypair -keyalg RSA -dname "$SOLR_CLIENT_CERT_DNAME" -validity $CERTIFICATE_VALIDITY -alias ssl.repo.client -keypass kT9X6oe68t -keystore "$CERTIFICATE_HOME/ssl.repo.client.keystore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
"$JAVA_HOME/bin/keytool" -exportcert -alias ssl.repo.client -file "$CERTIFICATE_HOME/ssl.repo.client.crt" -keystore "$CERTIFICATE_HOME/ssl.repo.client.keystore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
# Create trust relationship between repository and solr
"$JAVA_HOME/bin/keytool" -importcert -noprompt -alias ssl.repo.client -file "$CERTIFICATE_HOME/ssl.repo.client.crt" -keystore "$CERTIFICATE_HOME/ssl.truststore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
# Create trust relationship between repository and itself - used for searches
"$JAVA_HOME/bin/keytool" -importcert -noprompt -alias ssl.repo -file "$CERTIFICATE_HOME/ssl.repo.crt" -keystore "$CERTIFICATE_HOME/ssl.truststore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
# Create trust relationship between solr and repository
"$JAVA_HOME/bin/keytool" -importcert -noprompt -alias ssl.repo -file "$CERTIFICATE_HOME/ssl.repo.crt" -keystore "$CERTIFICATE_HOME/ssl.repo.client.truststore" -storetype "$STORE_TYPE" -storepass kT9X6oe68t
# Export repository keystore to pkcs12 format for browser compatibility
"$JAVA_HOME/bin/keytool" -importkeystore -srckeystore "$CERTIFICATE_HOME/ssl.keystore" -srcstorepass kT9X6oe68t -srcstoretype "$STORE_TYPE" -srcalias ssl.repo -srckeypass kT9X6oe68t -destkeystore "$CERTIFICATE_HOME/browser.p12" -deststoretype pkcs12 -deststorepass alfresco -destalias ssl.repo -destkeypass alfresco

# Ensure keystore dir actually exists
mkdir -p "$ALFRESCO_KEYSTORE_HOME"

# Back up old files
cp "$ALFRESCO_KEYSTORE_HOME/ssl.keystore" "$ALFRESCO_KEYSTORE_HOME/ssl.keystore.old"
cp "$ALFRESCO_KEYSTORE_HOME/ssl.truststore" "$ALFRESCO_KEYSTORE_HOME/ssl.truststore.old"
cp "$ALFRESCO_KEYSTORE_HOME/browser.p12" "$ALFRESCO_KEYSTORE_HOME/browser.p12.old"
cp "$SOLR_HOME/workspace-SpacesStore/conf/ssl.repo.client.keystore" "$SOLR_HOME/workspace-SpacesStore/conf/ssl.repo.client.keystore.old"
cp "$SOLR_HOME/workspace-SpacesStore/conf/ssl.repo.client.truststore" "$SOLR_HOME/workspace-SpacesStore/conf/ssl.repo.client.truststore.old"
cp "$SOLR_HOME/archive-SpacesStore/conf/ssl.repo.client.keystore" "$SOLR_HOME/archive-SpacesStore/conf/ssl.repo.client.keystore.old"
cp "$SOLR_HOME/archive-SpacesStore/conf/ssl.repo.client.truststore" "$SOLR_HOME/archive-SpacesStore/conf/ssl.repo.client.truststore.old"
cp "$SOLR_HOME/templates/test/conf/ssl.repo.client.keystore" "$SOLR_HOME/templates/test/conf/ssl.repo.client.keystore.old"
cp "$SOLR_HOME/templates/test/conf/ssl.repo.client.truststore" "$SOLR_HOME/templates/test/conf/ssl.repo.client.truststore.old"
cp "$SOLR_HOME/templates/store/conf/ssl.repo.client.keystore" "$SOLR_HOME/templates/store/conf/ssl.repo.client.keystore.old"
cp "$SOLR_HOME/templates/store/conf/ssl.repo.client.truststore" "$SOLR_HOME/templates/store/conf/ssl.repo.client.truststore.old"

# Install the new files
cp "$CERTIFICATE_HOME/ssl.keystore" "$ALFRESCO_KEYSTORE_HOME/ssl.keystore"
cp "$CERTIFICATE_HOME/ssl.truststore" "$ALFRESCO_KEYSTORE_HOME/ssl.truststore"
cp "$CERTIFICATE_HOME/browser.p12" "$ALFRESCO_KEYSTORE_HOME/browser.p12"
cp "$CERTIFICATE_HOME/ssl.repo.client.keystore" "$SOLR_HOME/workspace-SpacesStore/conf/ssl.repo.client.keystore"
cp "$CERTIFICATE_HOME/ssl.repo.client.truststore" "$SOLR_HOME/workspace-SpacesStore/conf/ssl.repo.client.truststore"
cp "$CERTIFICATE_HOME/ssl.repo.client.keystore" "$SOLR_HOME/archive-SpacesStore/conf/ssl.repo.client.keystore"
cp "$CERTIFICATE_HOME/ssl.repo.client.truststore" "$SOLR_HOME/archive-SpacesStore/conf/ssl.repo.client.truststore"
cp "$CERTIFICATE_HOME/ssl.repo.client.keystore" "$SOLR_HOME/templates/test/conf/ssl.repo.client.keystore"
cp "$CERTIFICATE_HOME/ssl.repo.client.truststore" "$SOLR_HOME/templates/test/conf/ssl.repo.client.truststore"
cp "$CERTIFICATE_HOME/ssl.repo.client.keystore" "$SOLR_HOME/templates/store/conf/ssl.repo.client.keystore"
cp "$CERTIFICATE_HOME/ssl.repo.client.truststore" "$SOLR_HOME/templates/store/conf/ssl.repo.client.truststore"

echo "Certificate update complete"
echo "Please ensure that you set dir.keystore=$ALFRESCO_KEYSTORE_HOME in alfresco-global.properties"
