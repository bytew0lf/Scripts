#!/bin/bash
clear

GO=https://golang.org/dl/go1.15.3.linux-amd64.tar.gz
GO_sig="010a88df924a81ec21b293b5da8f9b11c176d27c0ee3962dc1738d2352d3c02d"

GETH=https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.9.23-8c2f2715.tar.gz
GETH_sig=https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.9.23-8c2f2715.tar.gz.asc

GETH_plus=https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.9.23-8c2f2715.tar.gz
GETH_plus_sig=https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.9.23-8c2f2715.tar.gz.asc

NODEJS=https://nodejs.org/dist/v12.19.0/node-v12.19.0-linux-x64.tar.xz
NODEJS_sig=https://nodejs.org/dist/v12.19.0/SHASUMS256.txt.asc


wget $GO
wget $GETH_plus
wget $GETH_plus_sig
wget $NODEJS
wget $NODEJS_sig

SHA256=$(sha256sum $(basename $GO) | awk '{print $1}')
if [[ "$GO_sig" != "$SHA256" ]]; then
    echo "Downloaded Go package is corrupt!" >&2
    exit 1
fi

#Import Go Ethereum Linux Builder Fingerprint from keyserver
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys FDE5A1A044FA13D2F7ADA019A61A13569BA28146
SIGCHECK=$(gpg --verify $(basename $GETH_plus_sig) 2>&1 | grep Good) #| awk '{ print $2 $3 }')

if [[ -z $SIGCHECK ]]; then
    echo "Geth package signature missmatch!" >&2
    exit 1
fi

echo "Installing Go"
echo "Please enter the Root password"
su -c "tar -C /usr/local -xzf $(basename $GO)"

echo "Please enter the Root password"
su -c 'echo -e "\nexport PATH=\$PATH:/usr/local/go/bin" >> /etc/profile'

source /etc/profile
export PATH=$PATH:/usr/local/go/bin

echo "Extracting GETH + Tools"
tar -xvf $(basename $GETH_plus)
pushd $(basename $GETH_plus .tar.gz)
su -c 'mkdir /usr/local/geth && cp -r . /usr/local/geth/ && echo -e "\nexport PATH=\$PATH:/usr/local/geth" >> /etc/profile'
popd

source /etc/profile
export PATH=$PATH:/usr/local/geth

# Install NodeJS
# Import the NodeJS Fingerprints for Signature check of the signed SHA256Sums
gpg --keyserver pool.sks-keyservers.net --recv-keys 4ED778F539E3634C779C87C6D7062848A1AB005C
gpg --keyserver pool.sks-keyservers.net --recv-keys 94AE36675C464D64BAFA68DD7434390BDBE9B9C5
gpg --keyserver pool.sks-keyservers.net --recv-keys 1C050899334244A8AF75E53792EF661D867B9DFA
gpg --keyserver pool.sks-keyservers.net --recv-keys 71DCFD284A79C3B38668286BC97EC7A07EDE3FC1
gpg --keyserver pool.sks-keyservers.net --recv-keys 8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600
gpg --keyserver pool.sks-keyservers.net --recv-keys C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8
gpg --keyserver pool.sks-keyservers.net --recv-keys C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C
gpg --keyserver pool.sks-keyservers.net --recv-keys DD8F2338BAE7501E3DD5AC78C273792F7D83545D
gpg --keyserver pool.sks-keyservers.net --recv-keys A48C2BEE680E841632CD4E44F07496B3EB3C1762
gpg --keyserver pool.sks-keyservers.net --recv-keys 108F52B48DB57BB0CC439B2997B01419BD92F80A
gpg --keyserver pool.sks-keyservers.net --recv-keys B9E2F5981AA6E0CD28160D9FF13993A75599653C

SIGCHECK=$(gpg --verify $(basename $NODEJS_sig) 2>&1 | grep Good)

if [[ -z $SIGCHECK ]]; then
    echo "Node JS checksum file signature missmatch!" >&2
    exit 1
fi

NODEJS_CHECKSUM=$(grep $(basename $NODEJS) $(basename $NODEJS_sig) | sha256sum -c - | grep OK)

if [[ -z $NODEJS_CHECKSUM ]]; then
    echo "Node JS checksum missmatch!" >&2
    exit 1
fi

# Install the package
su -c "mkdir /usr/local/lib/nodejs && tar -xJvf $(basename $NODEJS) -C /usr/local/lib/nodejs && echo -e \"\nexport PATH=\$PATH:/usr/local/lib/nodejs/$(basename $NODEJS .tar.xz)/bin\" >> /etc/profile"

