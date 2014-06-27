# distro
distro=$(sed -rn 's/^([a-zA-Z]+)\s.*/\1/p' /etc/issue)

# path to install directory
ipath=/usr/local

# path to source directory
spath=/usr/local/src
