#!/bin/bash -e

case "$PACKER_BUILDER_TYPE" in
	parallels-iso)
		# Preserve installer logs.
		mv /var/log/pacman.log /var/log/pacman.log.preserve

		# Install development tools.
		pacman -Sy --noconfirm gcc linux-headers make

		# Mount the ISO.
		mount -o loop,ro /dev/shm/prl-tools-lin.iso /mnt

		# The Parallels Tools installer doesn't really properly support Arch Linux. It expects dkms and partx to be
		# installed, even though they're not really needed (kpartx is necessary only for `prlctl backup` functionality).
		ln -s true /bin/dkms
		ln -s true /bin/kpartx

		# It also expects to install startup scripts into /etc/init.d which doesn't exist on Arch. OK, whatever.
		mkdir /etc/init.d

		# Install Parallels Tools.
		/mnt/install --install-unattended

		# Remove dummies.
		rm /bin/dkms /bin/kpartx

		# Unmount the ISO.
		umount /mnt

		# Remove development tools.
		pacman -Rsn --noconfirm gcc linux-headers make

		# Restore installer logs
		mv /var/log/pacman.log.preserve /var/log/pacman.log
		;;

	virtualbox-iso)
		# Install VirtualBox Guest Additions.
		pacman -Sy --noconfirm virtualbox-guest-modules-arch virtualbox-guest-utils-nox
		;;

	vmware-iso)
		# Install open-vm-tools.
		pacman -Sy --noconfirm open-vm-tools

		# Create HGFS mount point.
		mkdir /mnt/hgfs

		# Enable Open-VM-Tools.
		systemctl enable vmtoolsd.service
		;;
esac

# Create the vagrant user.
groupadd -g 1000 vagrant
useradd -g vagrant -m -u 1000 vagrant
echo vagrant:vagrant | chpasswd

# Give the vagrant user sudo privileges.
cat > /etc/sudoers.d/vagrant <<-EOF
	vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/vagrant

# Install the Vagrant insecure public SSH key.
mkdir /home/vagrant/.ssh
curl -LsSo /home/vagrant/.ssh/authorized_keys https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod -R go-rwx /home/vagrant/.ssh

# Remove Pacman caches.
rm -r /var/cache/pacman/*

# Restore the sshd configuration we altered during installation back to default (disable root login with password).
mv /etc/ssh/sshd_config.orig /etc/ssh/sshd_config

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
		resize2fs /dev/sda1
		;;
	qemu)
		dd if=/dev/zero of=/dev/vda1 seek=8 bs=1M || true
		resize2fs /dev/vda2
		;;
esac

# Remove the root password now that we're done with it.
usermod -p '*' root
