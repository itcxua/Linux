#!/bin/sh CreateSelfSignCertTermux.sh

## ========================
## create a self-signed SSL Certificate ##
## ========================

apt -y install openssl*

# Step 1: Generate a Private Key
openssl genrsa -des3 -out server.key 1024

# Step 2: Generate a CSR (Certificate Signing Request)
openssl req -new -key server.key -out server.csr

# Step 3: Remove Passphrase from Key
cp server.key server.key.org
openssl rsa -in server.key.org -out server.key

# Step 4: Generating a Self-Signed Certificate3
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Step 5: Installing the Private Key and Certificate
cp server.crt $PREFIX/local/apache/conf/ssl.crt
cp server.key $PREFIX/local/apache/conf/ssl.key

SSLEngine on
SSLCertificateFile $PREFIX/local/apache/conf/ssl.crt/server.crt
SSLCertificateKeyFile $PREFIX/local/apache/conf/ssl.key/server.key
SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown
CustomLog logs/ssl_request_log \
   "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"

# Step 7: Restart Apache and Test

# /etc/init.d/httpd stop
# /etc/init.d/httpd stop

# https://webits.com.ua

echo "#=== END ===#"