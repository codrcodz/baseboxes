#!/bin/dash -e

export DEBIAN_FRONTEND=noninteractive

case $(uname -m) in
	i686) 	headers=linux-headers-686-pae ;;
	x86_64)	headers=linux-headers-amd64 ;;
esac

case "$PACKER_BUILDER_TYPE" in
        parallels-iso)
		# Preserve installer logs.
		for file in /var/log/apt /var/log/dpkg.log; do
			mv $file $file.preserve
		done

		# Install development tools.
		apt-get --no-install-recommends -y install gcc kpartx $headers make

		# Mount the ISO.
		mount -o loop,ro /dev/shm/prl-tools-lin.iso /mnt

		# Install Parallels Tools.
		/mnt/install --install-unattended

		# Unmount the ISO.
		umount /mnt

		# Correct a syntax error in the startup script.
		sed -i 's/\\)$/)\\/' /etc/init/prl-x11.conf

		# Remove development tools.
		apt-get --purge -y autoremove binutils cpp cpp-4.9 gcc kpartx $headers libcloog-isl4 libisl10 libmpc3 libmpfr4 make

		# Restore APT logs.
		for file in /var/log/apt /var/log/dpkg.log; do
			rm -r $file
			mv $file.preserve $file
		done
		;;

	virtualbox-iso)
		# Preserve installer logs.
		for file in /var/log/apt /var/log/dpkg.log; do
			mv $file $file.preserve
		done

		# Install development tools.
		apt-get --no-install-recommends -y install binutils bzip2 cpp gcc $headers make

		# Mount the ISO.
		mount -o loop,ro /dev/shm/VBoxGuestAdditions.iso /mnt

		# Install the guest additions.
		/mnt/VBoxLinuxAdditions.run

		# Unmount the ISO.
		umount /mnt

		# Remove development tools.
		apt-get --purge -y autoremove binutils bzip2 cpp cpp-4.9 gcc $headers libcloog-isl4 libisl10 libmpc3 libmpfr4 make

		# Restore APT logs.
		for file in /var/log/apt /var/log/dpkg.log; do
			rm -r $file
			mv $file.preserve $file
		done
		;;

        vmware-iso)
		# Preserve installer logs.
		for file in /var/log/apt /var/log/dpkg.log; do
			mv $file $file.preserve
		done

		# Install development tools.
		apt-get --no-install-recommends -y install gcc $headers make perl

		# Mount the ISO.
		mount -o loop,ro /dev/shm/linux.iso /mnt

		# Extract the tools distribution.
		tar xzCf /tmp /mnt/VMwareTools-*.tar.gz

		# Unmount the ISO.
		umount /mnt

		# Install the tools.
		/tmp/vmware-tools-distrib/vmware-install.pl -d -f

		# Reclaim some wasted disk space.
		case $(uname -m) in
			i686)
				rm -r /usr/lib/vmware-tools/bin64 /usr/lib/vmware-tools/lib64
				rm -r /usr/lib/vmware-tools/plugins64 /usr/lib/vmware-tools/sbin64
			;;
			x86_64)
				rm -r /usr/lib/vmware-tools/bin32 /usr/lib/vmware-tools/lib32
				rm -r /usr/lib/vmware-tools/plugins32 /usr/lib/vmware-tools/sbin32
			;;
		esac

		# Remove the distribution.
		rm -r /tmp/vmware-tools-distrib

		# Remove development tools.
		apt-get --purge -y autoremove binutils cpp cpp-4.9 gcc $headers libcloog-isl4 libisl10 libmpc3 libmpfr4 make perl perl-modules

		# Restore APT logs.
		for file in /var/log/apt /var/log/dpkg.log; do
			rm -r $file
			mv $file.preserve $file
		done
		;;
esac

# Create the vagrant user and group.
groupadd -g 1000 vagrant
useradd -g vagrant -m -s /bin/bash -u 1000 vagrant
echo vagrant:vagrant | chpasswd

# Give the vagrant user sudo privileges.
cat > /etc/sudoers.d/vagrant <<-EOF
	vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/vagrant

# Install the Vagrant insecure public SSH key.
mkdir /home/vagrant/.ssh
wget -nv -O /home/vagrant/.ssh/authorized_keys --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod -R go-rwx /home/vagrant/.ssh

# Turn off DNS lookups in SSHD per Vagrant recommendation.
cat >> /etc/ssh/sshd_config <<-EOF
	UseDNS no
EOF

# Clean up upgraded configuration files.
find / -xdev -name \*.dpkg-old -delete

# Remove DHCP leases.
rm -f /var/lib/dhcp/*

# Remove udev rules specific to the Packer build VM.
[ -f /etc/udev/rules.d/70-persistent-net.rules ] && sed -i 6,\$d /etc/udev/rules.d/70-persistent-net.rules

# Clear APT cache.
apt-get clean
find /var/lib/apt/lists -type f -delete

# Remove installer logs.
rm -r /var/log/installer

# Restore the sshd configuration we altered during installation back to default (disable root login with password).
mv /etc/default/ssh.orig /etc/default/ssh

# Clear /tmp.
find /tmp -mindepth 1 -delete

# Write zeroes to all free space to allow it to be reclaimed from the virtual disk image.
# dd will return an error code (device full) so hide it from `set -e`.
# Then expand the root filesystem to the full size of the device.
dd if=/dev/zero of=/zero bs=1M || true
rm /zero
swapoff -a
case "$PACKER_BUILDER_TYPE" in
        parallels-iso|virtualbox-iso|vmware-iso)
                dd if=/dev/zero of=/dev/sdb seek=8 bs=1M || true
                resize2fs -p /dev/sda1
                ;;
        qemu)
                dd if=/dev/zero of=/dev/vda1 seek=8 bs=1M || true
                resize2fs -p /dev/vda2
                ;;
esac

# Remove root password now that we're done with it.
usermod -p '*' root
