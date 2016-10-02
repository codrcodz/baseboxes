#!/bin/bash -e

# Remove any old kernels.
rpm -q kernel | grep -Fv kernel-$(uname -r) | xargs -r yum -y erase

case "$PACKER_BUILDER_TYPE" in
	parallels-iso)
		# Preserve Yum metadata.
		mv /var/lib/yum /var/lib/yum.preserve

		# Install development tools.
		yum -y install gcc kernel-devel perl

		# Mount the ISO.
		mount -o loop,ro /dev/shm/prl-tools-lin.iso /mnt

		# Install Parallels Tools.
		/mnt/install --install-unattended

		# Unmount the ISO.
		umount /mnt

		# Remove development tools.
		yum -y history undo last

		# Restore Yum metadata.
		rm -r /var/lib/yum
		mv /var/lib/yum.preserve /var/lib/yum
		;;

	virtualbox-iso)
		# Preserve Yum metadata.
		mv /var/lib/yum /var/lib/yum.preserve

		# Install development tools.
		yum -y install gcc kernel-devel perl

		# Mount the ISO.
		mount -o loop,ro /dev/shm/VBoxGuestAdditions.iso /mnt

		# Install the guest additions.
		/mnt/VBoxLinuxAdditions.run

		# Unmount and remove the ISO.
		umount /mnt

		# Remove development tools.
		yum -y history undo last

		# Restore Yum metadata.
		rm -r /var/lib/yum
		mv /var/lib/yum.preserve /var/lib/yum
		;;

	vmware-iso)
		# Install prerequisites.
		yum -y install fuse-libs perl

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
		;;
esac

# Create the vagrant user.
groupadd -g 1000 vagrant
useradd -g vagrant -u 1000 vagrant
passwd --stdin vagrant <<<vagrant

# Give the vagrant user sudo privileges.
cat > /etc/sudoers.d/vagrant <<-EOF
	vagrant ALL=(ALL) NOPASSWD: ALL
	Defaults:vagrant !requiretty
EOF
chmod 0440 /etc/sudoers.d/vagrant

# Install the Vagrant insecure public SSH key.
mkdir /home/vagrant/.ssh
curl -LsSo /home/vagrant/.ssh/authorized_keys https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod -R go-rwx /home/vagrant/.ssh

# Turn off DNS lookups by sshd per Vagrant recommendation.
sed -i -e '/^#UseDNS yes$/s//UseDNS no/' /etc/ssh/sshd_config

# Remove DHCP leases.
rm -f /var/lib/dhclient/*

# Add DEVICE specification inexplicably missing from NIC configuration.
[ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ] && sed -i '2iDEVICE="eth0"' /etc/sysconfig/network-scripts/ifcfg-eth0

# Remove NIC details specific to the Packer build VM.
sed -i -e /^HWADDR=/d -e /^UUID=/d /etc/sysconfig/network-scripts/ifcfg-eth0

# Remove udev rules specific to the Packer build VM.
sed -i 7,\$d /etc/udev/rules.d/70-persistent-cd.rules /etc/udev/rules.d/70-persistent-net.rules

# Remove Yum caches.
rm -r /var/cache/yum/*

# Remove installer logs.
rm -r /root/anaconda-ks.cfg /root/install.* /var/log/anaconda.*

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
		dd if=/dev/zero of=/dev/sdb1 seek=8 bs=1M || true
		resize2fs -p /dev/sda1
		;;
	qemu)
		dd if=/dev/zero of=/dev/vda1 seek=8 bs=1M || true
		resize2fs -p /dev/vda2
		;;
esac

# Remove the root password now that we're done with it.
usermod -p '*' root
