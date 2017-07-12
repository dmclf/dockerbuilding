FROM centos:6
MAINTAINER "DMcLF" <dmclf@noreply.github.com>

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm

RUN yum update -y 

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
  coreutils

# Expose web ports for testing
EXPOSE 80 443

#CMD /app/build.sh
ENTRYPOINT /app/build.sh
