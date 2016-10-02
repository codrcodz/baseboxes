#!/bin/bash -e

# Remove any old kernels.
rpm -q kernel | grep -Fv kernel-$(uname -r) | xargs -r yum -y remove

case "$PACKER_BUILDER_TYPE" in
	parallels-iso)
		# Preserve Yum metadata.
		mv /var/lib/yum /var/lib/yum.preserve

		# Install development tools.
		yum -y install checkpolicy gcc kernel-devel perl selinux-policy-devel

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
		yum -y install bzip2 gcc kernel-devel

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

		# NetworkManager has been seen to fail when a virtio-net device is used and multiple NICs are present.
		# Disabling consistent device naming prevents this.
		grubby --update-kernel=ALL --args=net.ifnames=0
		;;

	vmware-iso)
		# Install prerequisites.
		yum -y install fuse fuse-libs perl net-tools policycoreutils-python

		# Preserve Yum metadata.
		mv /var/lib/yum /var/lib/yum.preserve

		# Install development tools.
		yum -y install gcc kernel-devel

		# Mount the ISO.
		mount -o loop,ro /dev/shm/linux.iso /mnt

		# Extract the tools distribution.
		tar xzCf /tmp /mnt/VMwareTools-*.tar.gz

		# Unmount the ISO.
		umount /mnt

		# Install the tools.
		/tmp/vmware-tools-distrib/vmware-install.pl -d -f

		# Reclaim some wasted disk space.
		rm -r /usr/lib/vmware-tools/bin32 /usr/lib/vmware-tools/lib32 /usr/lib/vmware-tools/plugins32 /usr/lib/vmware-tools/sbin32

		# Remove the distribution.
		rm -r /tmp/vmware-tools-distrib

		# Remove development tools.
		yum -y history undo last

		# Restore Yum metadata.
		rm -r /var/lib/yum
		mv /var/lib/yum.preserve /var/lib/yum
		;;

	qemu)
		sed -i '2iDEVICE="eth0"' /etc/sysconfig/network-scripts/ifcfg-$(basename /sys/class/net/eth0)
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
rm -f /var/lib/NetworkManager/*

# Add DEVICE specification inexplicably missing from NIC configuration.
[ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ] && sed -i '2iDEVICE="eth0"' /etc/sysconfig/network-scripts/ifcfg-eth0

# Remove NIC details specific to the Packer build VM.
sed -i -e /^HWADDR=/d -e /^UUID=/d /etc/sysconfig/network-scripts/ifcfg-$(basename /sys/class/net/e*)

# Remove Yum caches.
rm -r /var/cache/yum/*

# Remove installer logs.
rm -r /root/anaconda-ks.cfg /var/log/anaconda

# Clear /tmp.
find /tmp -mindepth 1 -delete

# Write zeroes to all free space to allow it to be reclaimed from the virtual disk image.
# dd will return an error code (device full) so hide it from `set -e`.
# Then expand the root filesystem to the full size of the device.
dd if=/dev/zero of=/zero bs=1M || true
rm /zero
xfs_growfs /
swapoff -a
case "$PACKER_BUILDER_TYPE" in
	parallels-iso|virtualbox-iso|vmware-iso)
		dd if=/dev/zero of=/dev/sdb1 seek=8 bs=1M || true
		;;
	qemu)
		dd if=/dev/zero of=/dev/vda1 seek=8 bs=1M || true
		;;
esac

# Remove the root password now that we're done with it.
usermod -p '*' root
