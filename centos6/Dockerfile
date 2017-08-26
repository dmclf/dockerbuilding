FROM centos:6
MAINTAINER "DMcLF" <dmclf@users.noreply.github.com>

# Expose web ports for testing
EXPOSE 80 443

RUN yum install -y \
  gcc \
  git \
  make \
  rpm-build \
  rpmdevtools \
  sudo \
  yum-utils \
  createrepo \
  openssl \
  coreutils \
  apr-devel apr-util-devel audit-libs audit-libs-devel autoconf automake binutils bison c-ares-devel coreutils docbook-style-xsl ed elfutils findutils fipscheck-devel flex gcc gdbm-devel gd-devel gettext gnome-libs-devel groff gtk2-devel ipset-devel iptables-devel iptables-ipv6 ipvsadm kernel kernel-devel kernel-headers krb5-devel libcap-devel libedit-devel libgcrypt-devel libidn-devel libnfnetlink-devel libnl-devel libpcap-devel libpng-devel libselinux-devel libtalloc-devel libtool libtool-ltdl-devel libX11-devel libxml2-devel libxslt libxslt-devel lksctp-tools-devel man mysql-devel ncurses ncurses-devel net-snmp-devel net-snmp-utils net-tools nss-devel openldap-devel pam-devel patch pcre-devel perl perl-devel perl-ExtUtils-Embed pkgconfig popt-devel postgresql-devel python-devel readline-devel rpm sed sqlite-devel systemtap-sdt-devel tcp_wrappers-devel tetex texi2html texinfo unixODBC-devel util-linux xauth zlib-devel

RUN yum update -y 

ENTRYPOINT /app/build.sh
