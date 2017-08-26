# dockerbuilding

clone & run start.sh

* provides
- bash:4.4 centos-patches where applicable
- bind:9.11.2 vanilla
- freeradius:3.0.15 vanilla
- httpd:2.2.34 vanilla
- keepalived:1.3.5 vanilla
- nginx:1.13.4 with ajp webdav-ext and auth-ldap modules as extras
- openssh:7.5p1 vanilla against 1.0.2l  (note, this might cause issues as default behaviour is now vanilla-openssh)
- openssl:1.0.2l with fips and centos-patches where applicable
- openssl-fips:2.0.16
- quagga:1.2.1 vanilla
- sudo:1.8.20p2 with selinux, disable-root and insults

* todo
- setup jenkins and automated tests for each buildproject
- add centos7 support
