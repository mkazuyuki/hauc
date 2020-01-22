#!/bin/sh

#export https_proxy=http://PROXY_SERVER:PORT/
#export http_proxy=http://PROXY_SERVER:PORT/

# HAUC
curl -O https://codeload.github.com/mkazuyuki/hauc/zip/master
unzip master
rm master

# EC
curl -O https://www.nec.com/en/global/prod/expresscluster/en/trial/zip/ecx41l_x64.zip
unzip -j ecx41l_x64.zip "*.rpm"
rm ecx41l_x64.zip
mv expresscls-4.1.1-1.x86_64.rpm hauc-master/cf/

##
## Preparing trial license files is needed
##
mv ECX4.x-lin1.key     hauc-master/cf/
mv ECX4.x-Rep-lin1.key hauc-master/cf/
mv ECX4.x-Rep-lin2.key hauc-master/cf/

# PUTTY
cd hauc-master/cf
curl -O https://www.chiark.greenend.org.uk/~sgtatham/putty/licence.html
curl -O https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe
curl -O https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe
curl -O https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe
curl -O http://strawberryperl.com/download/5.30.0.1/strawberry-perl-5.30.0.1-64bit.msi
curl -O http://archive.kernel.org/centos-vault/7.6.1810/isos/x86_64/CentOS-7-x86_64-DVD-1810.iso
cd ../..
