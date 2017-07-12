#!/bin/bash
logs=""


PACKAGER="ddamen"
V_OPENSSL="1:1.0.2l-1"
V_OPENSSH="1:7.5p1-1.1"
ssl_before=$($(openssl version) ciphers: $(openssl ciphers|tr \: "\012" | wc -l))
ssh_before=$(ssh -V 2>&1 | tr -d "\012")

# Create directories if not already present
mkdir -p ~/rpmbuild/{SPECS,SOURCES}
yum install -y createrepo  2>/dev/null >/dev/null
cat << EOF > /etc/yum.repos.d/local.repo
[local]
name=CentOS-\$releasever - local packages
baseurl=file:///root/rpmbuild/RPMS/
enabled=1
gpgcheck=0
protect=1
EOF
createrepo /root/rpmbuild/RPMS/

trackdir=$(head -n1 /etc/redhat-release |sed s/^.*elease\ //g | cut -f1 -d\. | awk '{print "done_"$1}')
if test ! -d /root/rpmbuild/SPECS/${trackdir}
then
mkdir /root/rpmbuild/SPECS/${trackdir}
fi

#for hash in openssl-fips:2.0.16 openssl:1.0.2l openssh:7.5p1 nginx:1.13.1 keepalived:1.3.5 httpd:2.2.32 bash:4.4
for hash in openssl-fips:2.0.16 openssl:1.0.2l
do
app=$(echo $hash | cut -f1 -d\:)
version=$(echo $hash | cut -f2 -d\:)

echo "Starting on $app $version !!"
start=$(date +%s)

specfile="/root/rpmbuild/SPECS/${app}-${version}.spec"
templfile="/root/rpmbuild/SPECS/${app}-${version}.TEMPL"


if test -f "$templfile"
then
cat ${templfile} | sed "s/__PACKAGER__/${PACKAGER}/g" | sed "s/__OPENSSLVERSION__/${V_OPENSSL}/g"  | sed "s/__OPENSSHVERSION__/${V_OPENSSH}/g" > ${specfile}
fi

if test ! -f "$specfile"
then
echo "Missing spec file for ${app}-${version} ($specfile)"
continue
fi

ok=1

rm -rf /root/rpmbuild/SOURCES/*
if test -d /root/rpmbuild/SOURCES_LOCAL/${app}
then
rsync -ra /root/rpmbuild/SOURCES_LOCAL/${app}/patches/ /root/rpmbuild/SOURCES/ --delete-after
rsync -ra /root/rpmbuild/SOURCES_LOCAL/${app}/sources/ /root/rpmbuild/SOURCES/
chown root:root -R ~/rpmbuild/SOURCES/
fi

ldconfig || sleep 5

if test -f "/root/rpmbuild/SPECS/${trackdir}/${hash}"
then
echo "recent build done for ${hash}"
yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm
continue
fi

yum $(yum repolist enabled | grep x86 | cut -f1 -d\/ | sed s/^/--disablerepo\ /g | tr "\012" \  ) upgrade -y

fail=0
case "$app" in
	openssl-fips)
	yum -y install openssl-fips	
	rpmquery -a | grep openssl-fips && continue
	;;

	openssl) 
	#check if we can upgrade already
	echo "Installing openssl-fips"
	yum -y install openssl-fips
	rpmquery -a | grep openssl-fips || echo "FAILED"
	rpmquery -a | grep openssl-fips || yum -y install~/rpmbuild/RPMS/x86_64/openssl-fips*rpm
	rpmquery -a | grep openssl-fips || echo "FAILED"
	sleep 5
	yum -y upgrade openssl || 	rpm -Uv --nodeps ~/rpmbuild/RPMS/x86_64/openssl*${version}*rpm
	openssl version  | grep "${version}" && continue
	#else we just want to be sure again we have fips installed
	echo "check for fips"
	rpmquery -a | grep openssl-fips || break
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


spectool -g -R $specfile 2>&1 | tee -a ~/rpmbuild/SPECS/${trackdir}/${hash}.buildlog
yum-builddep -y $specfile 2>&1 | tee -a ~/rpmbuild/SPECS/${trackdir}/${hash}.buildlog
rpmbuild -bb $specfile 2>&1 || fail=1 | tee -a ~/rpmbuild/SPECS/${trackdir}/${hash}.buildlog 

if test  $fail -eq 1
then
echo "rpmbuild -bb $specfile"
echo "rpmbuilding failed"
break
exit 1
else 
createrepo /root/rpmbuild/RPMS/
fi


case "$app" in

	openssl) echo "
	openssl tests
	"
	rpm -Uv --nodeps ~/rpmbuild/RPMS/x86_64/openssl*${version}*rpm 
	ok=0
	openssl version  | grep ${version} && ok=1

	if test $ok -eq 1;then
	echo ok
	else
	echo something wrong, removing rpms
	mkdir ~/rpmbuild/RPMS/broken/ 2>/dev/null
	mv -v ~/rpmbuild/RPMS/*/openssl*${version}*rpm ~/rpmbuild/RPMS/broken/
	fi
	;;
	openssl-fips)
	yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm
	;;
	openssh)
	yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm
	ssh -V 2>&1 | grep -i "${app}*${version}" && touch ~/rpmbuild/SPECS/${trackdir}/${hash}
	;;
	nginx)
	yum -y install ~/rpmbuild/RPMS/x86_64/${app}*${version}*rpm
	service nginx start && curl localhost && touch ~/rpmbuild/SPECS/${trackdir}/${hash}
	;;
	*) echo "no tests defined for $app"
	;;
esac
touch ~/rpmbuild/SPECS/${trackdir}/${hash}

## end of hash loop
timetaken=timetaken=$(($(date +%s) - $start))
logs+="$app took $timetaken seconds\n" 
echo "$(date) $app took $timetaken seconds" >> ~/rpmbuild/SPECS/${trackdir}/${hash}.log

done

echo "summary info"
echo "sslversion before: $ssl_before"
echo "sslversion    now: $(openssl version) ciphers: $(openssl ciphers|tr \: "\012" | wc -l)"
#echo "rpmquery: $(rpmquery -a | grep openss)"
echo "ssh before: $ssh_before"
echo "ssh    now: $(ssh -V 2>&1 | tr -d "\012")"
echo "nginx: $(nginx -v 2>&1 | tr -d "\012")"
echo "httpd: $(httpd -v 2>&1 | tr -d "\012")"
echo "bash: $(bash --version 2>&1 | tr -d "\012")"
echo ""
echo -ne "$logs\n"
