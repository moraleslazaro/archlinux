#!/usr/bin/env bash
# Arch Linux install process automation
# Run this script after connecting to the network

# Global variables
BLD=$(tput bold) # Bold text
RST=$(tput sgr0) # Reset text to normal color
PKG_LIST="https://geo.mirror.pkgbuild.com/iso/latest/arch/pkglist.x86_64.txt"

# Verify the boot mode
printf "Verifying the boot mode (${BLD}BIOS${RST} mode will not show anything)...\n"
ls /sys/firmware/efi/efivars

# Update the system clock
printf "Updating the system ${BLD}clock${RST}...\n"
timedatectl set-ntp true

# Format disk and create partitions
read -p "Enter disk name: " DISKNAME

# Verify the disk is valid
until [ -b "/dev/${DISKNAME}"  ]
do
   read -p "Invalid disk name. Try again: " DISKNAME
done

printf "${BLD}WARNING${RST}: All the information stored in "
printf "${BLD}/dev/${DISKNAME}${RST} will be erased\n"

# Create partitions using fdisk
# A simple layout with three partitions will be created:
# 1.  500MB  EFI   /dev/sda1 
# 2.    8GB  SWAP  /dev/sda2
# 3. (rest)  root  /dev/sda3
printf "Creating partitions using ${BLD}fdisk${RST}...\n"
(
    echo g      # Create a new empty GPT partition table
    echo n      # Add first partition
    echo 1      # Use partition number 1
    echo        # First sector (Accept default: 1)
    echo +500MB # Last sector or partition size
    echo n      # Add second partition
    echo 2      # Use partition number 2
    echo        # Next sector available if empty
    echo +8GB   # Last sector or partition size
    echo n      # Add third partition
    echo 3      # User partition number 3
    echo        # Next sector available
    echo        # Use the rest of the space available
    echo p      # Print partition table
    echo w      # Write partition table 
) | fdisk /dev/${DISKNAME}

# Format partitions
printf "Formatting partitions...\n"
mkfs.fat -F 32 /dev/sda1 # EFI partition
mkswap /dev/sda2         # SWAP parition
mkfs.ext4 /dev/sda3      # root parition

# Enable SWAP
printf "Enabling SWAP...\n"
swapon /dev/sda2

# Mount partitions
printf "Mounting partitions...\n"
mount -v /dev/sda3 /mnt # Root partition
mount -v --mkdir /dev/sda1 /mnt/boot  # EFI partition

# Install all the packages included in the live system
# instead of installing only 'base' 'linux' and 'linux-firmware'
printf "Installing packages...\n"
for package in $(curl -s ${PKG_LIST} | awk '{ print $1 }')
do
    pacstrap /mnt $package
done

# Generate fstab
printf "Generating ${BLD}fstab${RST}...\n"
genfstab -U /mnt >> /mnt/etc/fstab

# Enter chroot
printf "Entering ${BLD}chroot${RST}...\n"
arch-chroot /mnt

# Set the time zone
printf "Setting up the time zone to ${BLD}US - Eastern${RST}...\n"
ln -vsf /usr/share/zoneinfo/US/Eastern /etc/localtime

# Sync up hardware clock
printf "Setting up the hardware clock...\n"
hwclock --systohc

# Generate localization
printf "Setting up localization...\n"
sed -i s/"#en_US.UTF-8 UTF-8"/"en_US.UTF-8 UTF-8"/ /etc/locale.gen
locale-gen
printf "LANG=en_US.UTF-8\n" > /etc/locale.conf

# Save hostname
read -p "Enter hostname: " HOSTNAME
printf "${HOSTNAME}\n" > /etc/hostname

# Set root password
printf "Setting up ${BLD}root${RST} password...\n"
passwd

# Configure boot loader
printf "Setting up ${BLD}GRUB${RST}...\n"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Reboot
printf "Installation completed. Rebooting now...\n"
exit   # Exit chroot environment
reboot # Reboot the live system
