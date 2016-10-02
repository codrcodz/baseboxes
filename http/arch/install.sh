#!/bin/bash

set -e

case $(systemd-detect-virt) in
	qemu)
		parted -s /dev/vda mklabel msdos
		parted -s /dev/vda mkpart primary linux-swap 0% 1GiB
		parted -s /dev/vda mkpart primary ext4 1GiB 3GiB
		mkswap /dev/vda1
		swapon /dev/vda1
		mkfs.ext4 /dev/vda2
		mount /dev/vda2 /mnt
		;;
	*)
		parted -s /dev/sda mklabel msdos
		parted -s /dev/sda mkpart primary ext4 0% 2GiB
		mkfs.ext4 /dev/sda1
		mkswap /dev/sdb
		swapon /dev/sdb
		mount /dev/sda1 /mnt
		;;
esac

pacstrap /mnt base
genfstab -p /mnt >> /mnt/etc/fstab
ln -s /usr/share/zoneinfo/Etc/UTC /mnt/etc/localtime
hostname > /mnt/etc/hostname
cat > /mnt/etc/systemd/network/ethernet.network <<-EOF
	[Match]
	name=en*
	
	[Network]
	DHCP=yes
EOF
arch-chroot /mnt systemctl --no-reload enable systemd-networkd.service
ln -fs /run/systemd/resolve/resolv.conf /mnt/etc/resolv.conf
arch-chroot /mnt systemctl --no-reload enable systemd-resolved.service
arch-chroot /mnt mkinitcpio -p linux
echo root:packer | arch-chroot /mnt chpasswd
arch-chroot /mnt pacman -S --noconfirm grub openssh sudo

case $(systemd-detect-virt) in
	qemu)
		sfdisk -f --no-reread /dev/vda <<-EOF || true
			2048,2095104,82,
			2097152,,83,*
		EOF
		arch-chroot /mnt grub-install --target=i386-pc /dev/vda
		;;
	*)
		echo '2048,,83,*' | sfdisk -f --no-reread /dev/sda || true
		arch-chroot /mnt grub-install --target=i386-pc /dev/sda
		;;
esac

sed -i '/^GRUB_TIMEOUT=/s/=[0-9]\+$/=0/' /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
sed -i.orig '$aPermitRootLogin=yes' /mnt/etc/ssh/sshd_config
arch-chroot /mnt systemctl --no-reload enable sshd.socket
arch-chroot /mnt pacman -Syu

reboot
