#!/bin/bash -e

# Update packages.
dnf -y update

case $(uname -m) in
        i686)   headers=kernel-PAE-devel ;;
        x86_64) headers=kernel-devel ;;
esac

case "$PACKER_BUILDER_TYPE" in
	parallels-iso)
		# Preserve DNF metadata.
		mv /var/lib/dnf /var/lib/dnf.preserve

		# Install development tools.
		dnf -y install checkpolicy gcc $headers perl selinux-policy-devel tar

		# Mount the ISO.
		mount -o loop,ro /dev/shm/prl-tools-lin.iso /mnt

		# Install Parallels Tools.
		/mnt/install --install-unattended

		# Unmount the ISO.
		umount /mnt

		# Remove development tools.
		dnf -y history undo last

		# Restore DNF metadata.
		rm -r /var/lib/dnf /var/log/dnf.* /var/log/hawkey.log
		mv /var/lib/dnf.preserve /var/lib/dnf
		;;

	virtualbox-iso)
		# Preserve DNF metadata.
		mv /var/lib/dnf /var/lib/dnf.preserve

		# Install development tools.
		dnf -y install bzip2 gcc $headers policycoreutils-python-utils tar

		# Mount the ISO.
		mount -o loop,ro /dev/shm/VBoxGuestAdditions.iso /mnt

		# Install the guest additions.
		/mnt/VBoxLinuxAdditions.run

		# Unmount and remove the ISO.
		umount /mnt

		# Remove development tools.
		dnf -y history undo last

		# Restore DNF metadata.
		rm -r /var/lib/dnf /var/log/dnf.* /var/log/hawkey.log
		mv /var/lib/dnf.preserve /var/lib/dnf
		;;

	vmware-iso)
		# Install prerequisites.
		dnf -y install fuse fuse-libs policycoreutils-python-utils
		modprobe fuse

		# Preserve DNF metadata.
		mv /var/lib/dnf /var/lib/dnf.preserve

		# Install development tools.
		dnf -y install net-tools perl-File-Temp tar

		# Mount the ISO.
		mount -o loop,ro /dev/shm/linux.iso /mnt

		# Extract the tools distribution.
		tar xzCf /tmp /mnt/VMwareTools-*.tar.gz

		# Unmount the ISO.
		umount /mnt

		# Install the tools.
		/tmp/vmware-tools-distrib/vmware-install.pl --default --force-install

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
		dnf -y history undo last

		# Restore DNF metadata.
		rm -r /var/lib/dnf /var/log/dnf.* /var/log/hawkey.log
		mv /var/lib/dnf.preserve /var/lib/dnf
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
#sed -i -e '/^#UseDNS yes$/s//UseDNS no/' /etc/ssh/sshd_config

# Remove DHCP leases.
rm -f /var/lib/NetworkManager/*


# Remove NIC details specific to the Packer build VM.
sed -i /^UUID=/d /etc/sysconfig/network-scripts/ifcfg-$(basename /sys/class/net/e*)

# Remove DNF caches.
rm -r /var/cache/dnf/*

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
		dd if=/dev/zero of=/dev/sdb seek=8 bs=1M || true
		;;
	qemu)
		dd if=/dev/zero of=/dev/vda1 seek=8 bs=1M || true
		;;
esac

# Remove the root password now that we're done with it.
usermod -p '*' root
