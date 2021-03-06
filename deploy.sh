#!/usr/bin/env bash

# INSTALLATION PARAMETERS
# =======================

# SUGGESTED PARTITION SCHEME
# ==========================
# DEVICE       PARTITION                         SIZE
# /dev/sda1    Windows Recovery Environment      500MiB
# /dev/sda2    Windows ESP                       100MiB
# /dev/sda3    Microsoft Reserved Partition      16MiB
# /dev/sda4    Microsoft basic data partition    Arbitrary
# /dev/sda5    Linux ESP                         50MiB
# /dev/sda6    Linux Boot                        200MiB
# /dev/sda6    Linux Swap                        8GiB
# /dev/sda7    Linux Root                        Remaining space


TO_INSTALL=" \
base \
base-devel \
f2fs-tools \
sudo \
networkmanager \
openssh \
git \
zsh \
bat \
lsd \
neovim \
xclip \
flatpak \
noto-fonts \
noto-fonts-cjk \
noto-fonts-emoji \
mpv \
youtube-dl \
ntfs-3g \
libva-utils \
intel-ucode \
grub \
efibootmgr \
"

TO_INSTALL_AUR="yay-bin"


# ARGUMENT PARSING
# ================

LONGOPTS="efi-partition:,boot-partition:,swap-partition:,root-partition:" # partitioning
LONGOPTS="$LONGOPTS,hostname:,localtime:,language:,root-password:,user-name:,user-password:" # system configuration
LONGOPTS="$LONGOPTS,nvidia,intel" # video driver
LONGOPTS="$LONGOPTS,install-gnome:,install-kde:,install-firefox,install-chrome,install-chromium,install-brave,install-vscodium" # packages to install

OPTS=$(getopt -o h --long $LONGOPTS,help --name "$0" -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options, exiting..." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

while true; do
	case "$1" in
		--efi-partition)
			EFI_PARTITION="$2"
			shift 2
			;;
		--boot-partition)
			BOOT_PARTITION="$2"
			shift 2
			;;
		--swap-partition)
			SWAP_PARTITION="$2"
			shift 2
			;;
		--root-partition)
			ROOT_PARTITION="$2"
			shift 2
			;;
		--hostname)
			MY_HOSTNAME="$2"
			shift 2
			;;
		--localtime)
			LOCALTIME="$2"
			shift 2
			;;
		--language)
			LANGUAGE="$2"
			shift 2
			;;
		--root-password)
			ROOT_PASSWORD="$2"
			shift 2
			;;
		--user-name)
			USER_NAME="$2"
			shift 2
			;;
		--user-password)
			USER_PASSWORD="$2"
			shift 2
			;;
		--nvidia)
			INSTALL_NVIDIA=true
			shift
			;;
		--intel)
			INSTALL_INTEL=true
			shift
			;;
		--install-gnome)
			INSTALL_GNOME=true
			shift
			;;
		--install-kde)
			INSTALL_KDE=true
			shift
			;;
		--install-firefox)
			INSTALL_FIREFOX=true
			shift
			;;
		--install-chrome)
			INSTALL_CHROME=true
			shift
			;;
		--install-chromium)
			INSTALL_CHROMIUM=true
			shift
			;;
		--install-brave)
			INSTALL_BRAVE=true
			shift
			;;
		--install-vscodium)
			INSTALL_VSCODIUM=true
			shift
			;;
		--)
			shift
			break
			;;
		*)
			cat <<EOF
Usage: deploy.sh [OPTIONS]

Example: deploy.sh --efi-partition=/dev/sda5 --boot-partition=/dev/sda6 --swap-partition=/dev/sda7 --root-partition=/dev/sda8 \
                   --hostname=mq-desktop --localtime=Europe/Rome --language=en_US --root-password=password --user-name=manuel \
				   --nvidia --install-gnome --install-brave --install-vscodium

Options:
	--efi-partition <EFI_PARTITION>
	--boot-partition <BOOT_PARTITION>
	--swap-partition <SWAP_PARTITION>
	--root-partition <ROOT_PARTITION>
	--hostname <HOSTNAME>
	--localtime <LOCALTIME>
	--language <LANGUAGE>
	--root-password <ROOT_PASSWORD>
	--user-name <USER_NAME>
	--user-password <USER_PASSWORD>
	--nvidia
	--intel
	--install-gnome
	--install-kde
	--install-firefox
	--install-chrome
	--install-chromium
	--install-brave
	--install-vscodium
EOF
			exit 1
			;;
	esac
done

if [ -z "$EFI_PARTITION$BOOT_PARTITION$SWAP_PARTITION$ROOT_PARTITION$HOSTNAME$LOCALTIME$LANGUAGE$ROOT_PASSWORD$USER_NAME" ]; then
	echo "Argument(s) missing (use deploy.sh -h for more info), exiting..."
	exit 1
fi

if [ -z "$USER_PASSWORD" ]; then
	USER_PASSWORD="$ROOT_PASSWORD"
fi

if $INSTALL_NVIDIA; then
	TO_INSTALL="$TO_INSTALL nvidia vdpauinfo"
	if $INSTALL_CHROMIUM; then
		TO_INSTALL_AUR="$TO_INSTALL_AUR libva-vdpau-driver-chromium"
	else
		TO_INSTALL="$TO_INSTALL libva-vdpau-driver"
	fi
fi

if $INSTALL_INTEL; then
	TO_INSTALL="$TO_INSTALL intel-media-driver"
fi

if $INSTALL_GNOME; then
	TO_INSTALL="$TO_INSTALL gnome gnome-tweaks tilix python-nautilus"
fi

if $INSTALL_KDE; then
	TO_INSTALL="$TO_INSTALL plasma plasma-wayland-session kde-applications"
fi

if $INSTALL_FIREFOX; then
	TO_INSTALL="$TO_INSTALL firefox"
fi

if $INSTALL_CHROME; then
	TO_INSTALL_AUR="$TO_INSTALL_AUR google-chrome"
fi

if $INSTALL_CHROMIUM; then
	TO_INSTALL_AUR="$TO_INSTALL_AUR chromium-vaapi-bin chromium-widevine"
fi

if $INSTALL_BRAVE; then
	TO_INSTALL_AUR="$TO_INSTALL_AUR brave-bin"
fi

if $INSTALL_VSCODIUM; then
	TO_INSTALL_AUR="$TO_INSTALL_AUR vscodium-bin"
fi


# PRE-INSTALLATION
# ================

# update the system clock
timedatectl set-ntp true

# format the partitions
mkfs.vfat -F 32 $EFI_PARTITION
mkfs.ext4 -F $BOOT_PARTITION
mkfs.f2fs -f $ROOT_PARTITION
mkswap -f $SWAP_PARTITION
swapon $SWAP_PARTITION

# mount the file systems
mount $ROOT_PARTITION /mnt
mkdir /mnt/boot
mount $BOOT_PARTITION /mnt/boot
mkdir /mnt/efi
mount $EFI_PARTITION /mnt/efi

# INSTALLATION
# ============

# install the packages
pacstrap /mnt "$TO_INSTALL"

# CONFIGURE THE SYSTEM
# ====================

# generate the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# write the second part to be executed inside the chroot
cat <<EOF > /mnt/part2.sh
#!/usr/bin/env bash

aur-install() {
	su - $USER_NAME -c " \
		while [ "$1" ]; do
			if [ "$1" == "chromium-vaapi-bin" ]; then
				gpg --recv-keys EB4F9E5A60D32232BB52150C12C87A28FEAC6B20
			fi
			cd ~ && \
			git clone https://aur.archlinux.org/\$1.git && \
			cd \$1 && \
			makepkg -sirc --noconfirm && \
			cd ~ && \
			rm -rf \$1
			shift
		done
	"
}

# set the time zone
ln -sf /usr/share/zoneinfo/$LOCALTIME /etc/localtime

# run hwclock to generate /etc/adjtime
hwclock --systohc

# uncomment $LANGUAGE.UTF-8 UTF-8 in /etc/locale.gen
sed -i "s/#$LANGUAGE.UTF-8 UTF-8/$LANGUAGE.UTF-8 UTF-8/g" /etc/locale.gen

# generate the locale
locale-gen

# set the LANG variable in locale.conf
echo "LANG=$LANGUAGE.UTF-8" > /etc/locale.conf

# create the hostname file
echo "$MY_HOSTNAME" > /etc/hostname

# add matching entries to /etc/hosts
cat <<EOSF >> /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $MY_HOSTNAME.localdomain $MY_HOSTNAME
EOSF

# set the root password
echo "root:$ROOT_PASSWORD" | chpasswd

# MY STUFF
# ========

# create the user
useradd -m -s /usr/bin/zsh -G wheel $USER_NAME

# set the user password
echo "$USER_NAME:$USER_PASSWORD" | chpasswd

# add the wheel group (without password) to the sudoers file
echo "%wheel ALL=(ALL) NOPASSWD: ALL" | EDITOR='tee -a' visudo

# enable user namespaces
echo "kernel.unprivileged_userns_clone = 1" > /etc/sysctl.d/00-local-userns.conf

# configure vaapi and vdpau
case "$PRESET" in
	desktop) echo "LIBVA_DRIVER_NAME=vdpau\\\nVDPAU_DRIVER=nvidia" >> /etc/environment;;
	laptop) echo "LIBVA_DRIVER_NAME=iHD" >> /etc/environment;;
esac

# install aur packages
aur-install "$TO_INSTALL_AUR"

# add the user's dotfiles
su - $USER_NAME -c " \
	git clone https://github.com/mquarneti/dotfiles.git ~/.dotfiles && \
	chmod +x ~/.dotfiles/install.sh && \
	~/.dotfiles/install.sh \
"

# enable display manager service
case "$DESKTOP_ENVIRONMENT" in
	gnome) systemctl enable gdm.service;;
	kde)   systemctl enable sddm.service;;
esac

# enable networkmanager and bluetooth services
systemctl enable NetworkManager.service
systemctl enable bluetooth.service

# install grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# leave the chroot
exit
EOF

# make part2.sh executable
chmod +x /mnt/part2.sh

# execute part2.sh as chroot
arch-chroot /mnt /part2.sh

# remove part2.sh
rm /mnt/part2.sh

# umount all the partitions
umount -R /mnt

echo "installation complete"
