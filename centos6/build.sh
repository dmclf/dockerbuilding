#!/bin/bash
logs=""

function createlocalrepo ()
{
rpmquery -a | grep -q createrepo || yum install -y createrepo

cd /root/rpmbuild/RPMS/
createrepo .
cd -
sleep 2

if test ! -f /etc/yum.repos.d/local.repo
then 
cat << EOF > /etc/yum.repos.d/local.repo
[local]
name=Local
baseurl=file:///root/rpmbuild/RPMS/
enabled=1
gpgcheck=0

EOF
fi
}

yum install -y /root/rpmbuild/SOURCES_LOCAL/epel-release-latest-6.noarch.rpm


corelogfile='/root/rpmbuild/SPECS/core_buildlog.log'
PACKAGER="ddamen"
v_opensslfips="2.0.16"
v_openssl="1.0.2l"
v_openssh="7.6p1"
v_nginx="1.13.5"
v_keepalived="1.3.5"
v_httpd="2.2.34"
v_bind="9.11.2"
v_freeradius="3.0.15"
v_quagga="1.2.1"
v_sudo="1.8.20p2"
v_bash="4.4"

V_OPENSSL="1:${v_openssl}-1"
V_OPENSSH="1:${v_openssh}-1"
ssl_before="$(openssl version) ciphers: $(openssl ciphers|tr \: "\012" | wc -l)"
ssh_before=$(ssh -V 2>&1 | tr -d "\012")

loophashes="openssl-fips:${v_opensslfips} openssl:${v_openssl} sudo:${v_sudo} openssh:${v_openssh} nginx:${v_nginx} keepalived:${v_keepalived} httpd:${v_httpd} bind:${v_bind} quagga:${v_quagga} bash:${v_bash} freeradius:${v_freeradius}"

# Create directories if not already present
mkdir -p ~/rpmbuild/{SPECS,SOURCES,done} 

createlocalrepo


#quick loop to check for all spec files
for hash in $loophashes
do
app=$(echo $hash | cut -f1 -d\:)
version=$(echo $hash | cut -f2 -d\:)
specfile="/root/rpmbuild/SPECS/${app}-${version}.spec"
templfile="/root/rpmbuild/SPECS/${app}-${version}.TEMPL"

if test ! -f "$templfile"
then
echo "Missing template for ${app}-${version} ($templfile)" 
exit
fi
#make specfile from template
if test -f "$templfile"
then
cat ${templfile} | sed "s/__PACKAGER__/${PACKAGER}/g" | sed "s/__OPENSSLVERSION__/${V_OPENSSL}/g"  | sed "s/__OPENSSHVERSION__/${V_OPENSSH}/g" > ${specfile}
fi

if test ! -f "$specfile"
then
echo "Missing spec file for ${app}-${version} ($specfile)" | tee -a $corelogfile
exit
fi

yum-builddep -y $specfile 2>&1
done

# do the building
for hash in $loophashes
do
app=$(echo $hash | cut -f1 -d\:)
version=$(echo $hash | cut -f2 -d\:)

echo "$(date) Starting on $app $version !!" | tee -a $corelogfile
start=$(date +%s)

specfile="/root/rpmbuild/SPECS/${app}-${version}.spec"
templfile="/root/rpmbuild/SPECS/${app}-${version}.TEMPL"




ok=1

rm -rf /root/rpmbuild/SOURCES/*
if test -d /root/rpmbuild/SOURCES_LOCAL/${app}
then
if test -d /root/rpmbuild/SOURCES_LOCAL/${app}/patches;then rsync -ra /root/rpmbuild/SOURCES_LOCAL/${app}/patches/ /root/rpmbuild/SOURCES/  2>/dev/null;fi
if test -d /root/rpmbuild/SOURCES_LOCAL/${app}/sources;then rsync -ra /root/rpmbuild/SOURCES_LOCAL/${app}/sources/ /root/rpmbuild/SOURCES/  2>/dev/null;fi
chown root:root -R ~/rpmbuild/SOURCES/
fi

if test -f "/root/rpmbuild/SPECS/done/${hash}"
then
echo "recent build done for ${hash}" | tee -a $corelogfile
yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm | tee -a $corelogfile
continue
fi

fail=0
case "$app" in
	openssl) 
	rpmquery -a | grep openssl-fips || yum -y install ~/rpmbuild/RPMS/x86_64/openssl-fips*rpm || break
	;;

	openssh)
	rpm -Uv --nodeps ~/rpmbuild/RPMS/x86_64/openssl*rpm
	;;


	nginx)
pushd ~/rpmbuild/SOURCES
    git clone https://github.com/jcu-eresearch/nginx-custom-build.git

    #Headers More module
    git clone https://github.com/openresty/headers-more-nginx-module
    #pushd headers-more-nginx-module
    #git checkout v0.30rc1
    #popd

    #Fancy Index module
    git clone https://github.com/aperezdc/ngx-fancyindex.git
    #pushd ngx-fancyindex
    #git checkout ba8b4ec
    #popd

    #AJP module
    git clone https://github.com/yaoweibin/nginx_ajp_module.git
    #pushd nginx_ajp_module
    #git checkout bf6cd93
    #popd

    #LDAP authentication module
    git clone https://github.com/kvspb/nginx-auth-ldap.git
    #pushd nginx-auth-ldap
    #git checkout d0f2f82
    #popd

    #Shibboleth module
    git clone https://github.com/nginx-shib/nginx-http-shibboleth.git
    #pushd nginx-http-shibboleth
    #git checkout development
    #popd

    #DAV
    git clone https://github.com/arut/nginx-dav-ext-module.git
    #pushd nginx-dav-ext-module
    #git checkout master
    #popd

popd
	;;
esac

#set -o pipefail
yum-builddep -y $specfile 2>&1 | tee -a ~/rpmbuild/SPECS/done/${hash}.buildlog.builddep
spectool -g -R $specfile 2>&1 | tee -a ~/rpmbuild/SPECS/done/${hash}.buildlog.spectool
rpmbuild -bb $specfile 2>&1 | tee -a ~/rpmbuild/SPECS/done/${hash}.buildlog 
fail=${PIPESTATUS[0]}
#set +o pipefail

echo "debug rpmbuild result: ${fail} $specfile " |tee -a ~/rpmbuild/SPECS/done/${hash}.buildlog
if test  $fail -eq 1
then
echo "rpmbuild -bb $specfile" | tee -a $corelogfile
echo "rpmbuilding failed"  | tee -a $corelogfile
break
exit 1
else 
echo "rpmbuild $specfile ok" | tee -a $corelogfile
## repo update
createlocalrepo
## end of repo update
fi


createlocalrepo
case "$app" in

	openssl) echo "
	openssl tests
	"
	rpm -Uv --nodeps ~/rpmbuild/RPMS/x86_64/openssl*${version}*rpm 
	ok=0
	openssl version  | tee -a $corelogfile
	openssl version  | grep ${version} && ok=1

	if test $ok -eq 1;then
	echo $app ok | tee -a $corelogfile
	else
	echo $app something wrong, removing rpms | tee -a $corelogfile
	mkdir ~/rpmbuild/RPMS/broken/ 2>/dev/null
	mv -v ~/rpmbuild/RPMS/*/openssl*${version}*rpm ~/rpmbuild/RPMS/broken/
	fi
	;;

	openssl-fips)
	#yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm | tee -a $corelogfile
	yum -y install openssl-fips | tee -a $corelogfile
	;;

	openssh)
	#yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm | tee -a $corelogfile
	ssh -V 2>&1 | grep -i "${app}*${version}" | tee -a $corelogfile
	yum -y install openssh | tee -a $corelogfile
	;;

	nginx)
	#yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm | tee -a $corelogfile
	yum -y install nginx | tee -a $corelogfile
	service nginx start && curl localhost | tee -a $corelogfile
	;;

	*) echo "no tests defined for $app" | tee -a $corelogfile
	;;
esac
touch ~/rpmbuild/SPECS/done/${hash}

## end of hash loop
timetaken=timetaken=$(($(date +%s) - $start))
logs+="$app took $timetaken seconds\n" 
echo "$(date) $app took $timetaken seconds" >> ~/rpmbuild/SPECS/done/${hash}.log
echo "$(date) $app took $timetaken seconds"| tee -a $corelogfile
ls  -lan ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm | tee -a $corelogfile

done

echo "summary info:
sslversion before: $ssl_before
sslversion    now: $(openssl version) ciphers: $(openssl ciphers|tr \: "\012" | wc -l)
ssh before: $ssh_before
ssh    now: $(ssh -V 2>&1 | tr -d "\012")
nginx: $(nginx -v 2>&1 | tr -d "\012")
httpd: $(httpd -v 2>&1 | tr -d "\012")
bash: $(bash --version 2>&1 | tr -d "\012")
" | tee -a $corelogfile
echo -ne "$logs\n"| tee -a $corelogfile
