#!/usr/bin/env sh
#########################################################
##  ALARIS (Arch Linux / Artix Runit Installer Script) ##
#########################################################
# Author      : Agung p
# Create date : 19-04-20221
# Last update : 03-02-2022
# Description : This script to make installing Arch /
#               Artix (runit) more easy and save more time
# Source      : https://github.com/ap-id/ALARIS
# Usage       : - Boot the live enviroment
#               - Connect to internet
#               - run
#               'sudo sh -c "$(curl -L hrrps://raw.githubusercontent.com/agp-id/ALARIS/main/install.sh)"
#
# Thanks to   : - Allah SWT
#               - Internet & netizen
# License     : I don't really know, but it's free and open source. "wkwk (^-^)"
##########################################################

## Force exit
trap exit SIGINT

##Run as root
[[ $(id -u) != 0 ]] && echo "ROOT only !" && exit 1

# Needed  befor use _line()
clear

##====================================================================================
##------------------------------------------------------------------------------------
#                                   VARIABLE
##------------------------------------------------------------------------------------
## Packages
_base="base linux-firmware"
_kernel="linux"
_bootLoader="grub"
_bootOpt="os-prober ntfs-3g"
## Efi
[[ -d /sys/firmware/efi ]] && {
  _efi=1
  _bootLoader="$_bootLoader efibootmgr"
}
## Arch
_networkArch="connman wpa_supplicant"
## Artix
_initArtix="runit elogind-runit"
_networkArtix="connman-runit wpa_supplicant"
## Optional packages
_optPkg="neovim git opendoas intel-ucode broadcom-wl"
##-------------------------------------------------------------------------------
## Essential config
_timeZone="/usr/share/zoneinfo/Asia/Jakarta"
_locale="en_US.UTF-8"

## Pacman:I Love Candy
_iLoveCandy='sed -i --follow-symlinks \
            -e "s/.*Color/Color/" \
            -e "/.*ILove.*/d" \
            -e "/.*Color/a ILoveCandy" \
            -e "s/.*CheckSpace/CheckSpace/" \
            -e "s/.*VerbosePkgLists/VerbosePkgLists/" \
            -e "s/.*ParallelDown.*/ParallelDownloads\ =\ 2/" \
            /etc/pacman.conf'
##-------------------------------------------------------------------------------
## Decor
normal=$(tput sgr0) #normal
bold=$(tput bold) #bold
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
cyan=$(tput setaf 6)

Boldblue="$bold$blue"
Boldred="$bold$red"

##====================================================================================
##Title and line----------------------------------------------------------------------
## Usage: _line [symbol [color [title]]]
_line(){

    [[ -z $1 ]] && line="-" || line=$1
    [[ -n $2 ]] && declare -n color=$2 || color=$normal
    [[ -n "$3" ]] && {
        echo $color
        printf "%-$(( ($COLUMNS-${#3}-4)/2 ))s" | sed "s/ /$line/g"
        printf "| $3 |"
        printf "%-$(( ($COLUMNS-${#3}-3)/2 ))s${normal}" | sed "s/ /$line/g"
    } || {
        echo $color
        printf "%-${COLUMNS}s${normal}" | sed "s/ /$line/g"
    }
}

##About-----------------------------------------------------------------------------
_about(){

   _line = Boldblue
   _line = Boldred "ALARIS: Arch Linux / Artix Runit Installer Script"
   _line = Boldblue

   printf "   ${yellow}Thanks to: ${red}# ${green}${bold}ALLAH SWT${normal}
              ${red}# ${green}People on Internet


                ${bold}${purple}Features : ${normal}${red}- ${cyan}Suport Bios & Uefi(preferred)
                           ${normal}${red}- ${cyan}ext4 and fat32(Uefi boot) filesystem
                           ${normal}${red}- ${cyan}Partition: root, boot(optional BIOS), home(optional)
                           ${normal}${red}- ${cyan}Swapfile enable (Optional)
                           ${normal}${red}- ${cyan}Select your packages, Add/Remove (except main packages)
                           ${normal}${red}- ${cyan}Add user (Optional)


   ${bold}${yellow}Write by    : ${normal}Agung p
   ${bold}${yellow}Github      : ${normal}https://github.com/agp-id/ALARIS

   ${bold}${purple}Create date : ${normal}19-04-2021
   ${bold}${purple}Last Update : ${normal}${green}02-02-2022
   \n\n"
   read -n 1 -srp "${normal}Press any key "
   echo
}

##Internet Test-----------------------------------------------------------------------
_inet() {

    _line = Boldblue "Internet Connection"

    for ip in archlinux.org 1.1.1.1 8.8.8.8
    do
        echo "Pinging to: $ip"
        sleep 1
        ping -q -c 1 -W 1 $ip &>/dev/null && {
            echo -e "${green}\n----|Connected to internet${normal}"
            return
        } || {
            echo -e "${red}\n----|Disconnected!${normal}"
            echo
            read -n 1 -srp 'Please check your connection, and try again !'
            exit 1
        }
    done
}

##====================================================================================
#                                   SELECTING DISTRO
##------------------------------------------------------------------------------------
## Just match initial, "a" for arch or "A" for artix
_distro_select (){

    _line = Boldblue "Select Distro"

    printf "[${red}a${normal}]rch\n[${green}A${normal}]rtix\n---------\n${yellow}Insert initial ${red}a${normal}/${green}A${normal} : ${normal}"
    read -r _distro
        case $_distro in
            a* ) _distro="arch" ;;
            A* ) _distro="artix" ;;
            * ) clear
                echo "Just match first LETTER, can't you ?"
                _distro_select
                return ;;
        esac
        [[ $_distro = arch ]] &&
            echo -e "\n${Boldblue}Arch Linux${normal} selected.\n" ||
            echo -e "\n${Boldblue}Artix Linux${normal} selected.\n"
    read -n 1 -srp "${normal}Press any key "
    echo
}

##------------------------------------------------------------------------------------
#                                   PARTITION
##------------------------------------------------------------------------------------
_partition (){

    _line = Boldblue "Disk & Partitions"

    ## Unmount if already mounted
    umount -R /mnt/boot/efi /mnt/boot /mnt/home /mnt 2>&1 | grep "busy" && {
        echo "Please restart device, and try again!"
        exit 1
    }

    ## List detected Drive
    lsblk |egrep "NAME|disk" |sed '1 a\ ---------------' |awk '{print $1,$4}' |
        awk '$1=$1' FS=" " OFS="\t"

    printf "\n${red}[REQUIRED] ${green}DISK Letter?${normal} (i.e. $(lsblk |grep "disk" |
        awk '{print $1}' ORS=',' |sed 's/ /,/;s/.$//')): "
    read -r _drive
    if [[ ! $(lsblk -dno name |grep -x "$_drive") ]]; then
        clear
        echo  "${red}Drive ${purple}$_drive${red} not found, please make sure DRIVE exist in list below!${normal}"
        _partition
        return
    fi

    _line - yellow
    read -n 1 -srp "Please create/check your partition!  (press any key)"
    ## Create/check partition (manual)
    cfdisk /dev/"$_drive"

    clear
    _line = Boldblue "Select Partitions"
    ## List partition from selected Drive
    lsblk |egrep "NAME|$_drive.*part" |
        sed "s/.*$_drive/$_drive/;1 a\ --------------------------" |
        awk '{print $1,$4,$7}' FS=" " OFS="\t"

    ## Select ROOT partition & check
    printf "\n\n${red}[REQUIRED] ${cyan}ROOT partition${normal} (i.e. $_drive<DIGIT>): $_drive"
    read -r _root
        #[[ -n $_root ]] && [[ $(lsblk |egrep "$_drive$_root.*part") ]] || {
        if [[ -z $_root || ! $(lsblk |egrep "$_drive$_root") ]]; then
            clear
            echo "${red}Partition ${purple}/dev/$_drive$_root${red} not found!, please check again!${normal}"
            _partition
            return
        fi

    ## Select EFI partition & check
    if [[ $_efi = 1 ]]; then
        read -rp "${red}[REQUIRED] ${yellow}BOOT partition${normal} (i.e. $_drive<DIGIT>): $_drive" _boot
        if [[ -z $_boot ]]; then
            clear
            echo "${red}I think your device is ${purple}UEFI${red}, please create/select boot partition!${normal}"
            _partition
            return
        fi
    else
        read -rp "${purple}[OPTIONAL] ${cyan}BOOT partition${normal} (i.e. $_drive<DIGIT>): $_drive" _boot
    fi

        if [[ -z $_boot ]]; then
            :
        elif [[ -n $_boot && ! $(lsblk |egrep "$_drive$_boot") ]]; then
            clear
            echo "${red}Partition ${purple}/dev/$_drive$_boot${red} not found!, please check again!${normal}"
            _partition
            return
        elif [[ $_drive$_root = $_drive$_boot ]]; then
            clear
            echo "${purple}/dev/$_drive$_root${red} is root partition, select other!${normal}"
            _partition
            return
        fi

    ## Select HOME partition & check
    read -rp "${purple}[OPTIONAL] ${cyan}HOME partition${normal} (i.e. $_drive<DIGIT>): $_drive" _home
        #[[ -n $_home && ! $(lsblk |egrep "$_drive$_home.*part") ]]; then
        if  [[ -z $_home ]]; then
            :
        elif [[ ! $(lsblk |egrep "$_drive$_home") ]]; then
            clear
            echo "${red}Partition ${purple}/dev/$_drive$_home${red} not found!, please check again!${normal}"
            _partition
            return
        elif [[ $_drive$_home = $_drive$_root || $_drive$_home = $_drive$_boot ]]; then
            clear
            echo "${purple}/dev/$_drive$_boot${red} is root/boot partition, select other!${normal}"
            _partition
            return
        fi

   _swap_file
}
##Swap file------------------------------------------------------------------------------
_swap_file (){
    echo -e "\n${purple}[OPTIONAL] ${cyan}Enable swapfile${normal}, min 512MB."
    read -p "Insert size (MB): " _swapSize
    if [[ -z $_swapSize ]]; then
        :
    elif ! [[ $_swapSize =~ ^[-+]?[0-9]+$ ]]; then
        clear
        echo "${red}Digits only${normal}"
        _swap_file
        return
    elif (( $_swapSize < 512 )); then
        clear
        echo "${red}Minimal size 512MB${normal}"
        _swap_file
        return
    fi
}

##------------------------------------------------------------------------------------
#                                DEVICE & USER
##------------------------------------------------------------------------------------
_device_info (){

    _line = Boldblue "Device & User"
    _host_name
}

_host_name() {
    read -p "${red}[REQUIRED] ${cyan}Hostname     :${normal} " _hostName
    if [[ -z $_hostName ]]; then
        echo "Sorry can't empty!"
        _host_name
        return
    else _root_pass
    fi
}

_root_pass() {
    IFS= read -sp "${red}[REQUIRED] ${cyan}Root Password:${normal} " _rootPass1
    if [[ -z "$_rootPass1" ]]; then
        echo "Sorry can't empty!"
        _root_pass
        return
    fi
    echo
    IFS= read -sp "${cyan}         Retype Password:${normal} " _rootPass
    if [[ "$_rootPass1" != "$_rootPass" ]]; then
        echo "Password not match!"
        _root_pass
        return
    fi
}

_add_user (){
    echo
    read -p "${purple}[OPTIONAL] ${cyan}Add User     : ${normal}" _userName
    [[ -n $_userName ]] && _user_pass
}

_user_pass() {
    IFS= read -sp "${red}[REQUIRED] ${cyan}User Password: ${normal}" _userPass
    if [[ -z $_userPass ]]; then
        echo "Sorry can't empty!"
        _user_pass
        return
    fi
    echo
}

##------------------------------------------------------------------------------------
#                                Base and Packages
##------------------------------------------------------------------------------------
_pkg_select() {

   _line = Boldblue 'Packages Selection'
    read -ep "${yellow}Base & Kernel   : ${normal}$_base " -i "$_kernel " _kernel
        [[ -z $_kernel ]] && _kernel="linux "

    if [[ $_distro = arch ]]; then
        ## arch
        read -ep "${yellow}Network         : ${normal}" -i "$_networkArch " _service
    else
        ## artix
        read -ep "${yellow}Network         : ${normal}" -i "$_networkArtix " _service
        _service="$_initArtix $_service"
    fi

    read -ep "${yellow}Bootloader      : ${normal}$_bootLoader " -i "$_bootOpt " _bootOpt
    read -ep "${yellow}Other packages  : ${normal}" -i "$_optPkg " _optPkg

    _pkgs="$_base $_kernel $_service $_bootLoader $_bootOpt $_optPkg "


    _line = Boldblue "Locale Config"
    read -ep "${purple}Local Time      : ${normal}" -i "$_timeZone" _timeZone
    read -ep "${purple}Locale          : ${normal}" -i "$_locale" _locale
}

##------------------------------------------------------------------------------------
#                                   Mount Partition
##------------------------------------------------------------------------------------
_mount (){

    _line = Boldblue "Mounting Partitions"

    : | mkfs.ext4 /dev/"$_drive$_root"
    mount /dev/"$_drive$_root" /mnt

    if [[ $_efi = 1 ]]; then
        : | mkfs.fat -F32 /dev/"$_drive$_boot"
        mkdir -p /mnt/boot/efi
        mount /dev/"$_drive$_boot" /mnt/boot/efi
    elif [[ -n $_boot ]]; then
        : | mkfs.ext4 /dev/"$_drive$_boot"
        mkdir /mnt/boot
        mount /dev/"$_drive$_boot" /mnt/boot
    fi
    if [[ -n $_home ]]; then
        : | mkfs.ext4 /dev/"$_drive$_home"
        mkdir /mnt/home
        mount /dev/"$_drive$_home" /mnt/home
    fi
}

##------------------------------------------------------------------------------------
#                                   Installation
##------------------------------------------------------------------------------------
_install() {

    _line = Boldblue "Starting Installation"
    if [[ $_distro = arch && ! $(echo $_pkgs | grep "reflector") ]]; then
         echo "'reflector' will be install to update mirror arch. You can uninstall later."
         read -n 1 -srp "(press any key)"
         printf "\n\n"
         _pkgs="$_pkgs reflector"
    fi

    _install2 || {
        read -p "Installation not completed, try again ?   [Y/n] " _ins
        case $_ins in
            [nN]* )
                exit 1 ;;
            * )
                _install
                return ;;
        esac
    }
}
_install2() {
    if [[ $_distro = arch ]]; then
        ## arch
        timedatectl set-ntp true
        pacstrap /mnt --needed --noconfirm $_pkgs
    else
        ## artix
        basestrap /mnt --needed --noconfirm $_pkgs
    fi
}

##------------------------------------------------------------------------------------
#                                 Essential Configurations
##------------------------------------------------------------------------------------
_config() {

    _line = Boldblue "Generating fstab"

    if [[ $_distro = arch ]]; then
        ## arch
        genfstab -U /mnt > /mnt/etc/fstab && echo "--------|Done"
    else
        ## artix
        fstabgen -U /mnt > /mnt/etc/fstab && echo "--------|Done"
    fi
    CHROOT=$_distro


cat << EOF > /mnt/root/install.sh
##=========================================================================================
clear # needed before run _line

_line (){

    [[ -z \$1 ]] && line="-" || line=\$1
    [[ -n \$2 ]] && color=\$2 || color="$normal"
    [[ -n \$3 ]] && {
        echo \${color}
        printf "%-\$(( (\$COLUMNS-\${#3}-4)/2 ))s" | sed "s/ /\$line/g";
        printf "| \$3 |";
        printf "%-\$(( (\$COLUMNS-\${#3}-3)/2 ))s$normal" | sed "s/ /\$line/g"
    } || {
        echo \${color}
        printf "%-\${COLUMNS}s$normal" | sed "s/ /\$line/g";
    }
}

   _line = "$Boldblue" "Essential Configurations"
sleep 2

##-----------------------------------------
_line - "$blue" 'Time Zone'
##-----------------------------------------

ln -sf $_timeZone /etc/localtime
hwclock --systohc
echo -e "\n----|Done"

##----------------------------------------
_line - "$blue" 'Localization'
##----------------------------------------

echo "$_locale UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$_locale" > /etc/locale.conf
echo -e "\n----|Done"

##----------------------------------------
_line - "$blue" 'Pacman config'
##----------------------------------------

$_iLoveCandy && echo "----|Done"

##========================================
## arch
[[ $_distro = arch ]] && {
_line - "$blue" 'Update mirror'
##========================================

reflector --verbose --latest 5 --protocol https --sort rate \
--save /etc/pacman.d/mirrorlist
}

##----------------------------------------
_line - "$blue" 'Hostname & Localhost'
##----------------------------------------

echo "$_hostName" > /etc/hostname

cat << eof1 | tee /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 localdomain     $_hostName
eof1

##----------------------------------------
_line - "$blue" 'Network'
##----------------------------------------

[[ $_distro = arch ]] &&
## arch
systemctl enable connman || {
## artix
ln -s /etc/runit/sv/connmand /etc/runit/runsvdir/default/
}
echo -e "\n----|Done"

##----------------------------------------
_line - "$blue" 'NTP'
##----------------------------------------

echo -e "[General]\n
UseGatewaysAsTimeservers = false
FallbackTimeservers = pool.ntp.org,asia.pool.ntp.org,time1.google.com
" > /etc/connman/main.conf
echo -e "\n----|Done"

##----------------------------------------
_line - "$blue" 'Bootloader'
##----------------------------------------

[[ "$_efi" = 1 ]] &&
grub-install --target=x86_64-efi --efi-directory=/boot \
--bootloader-id=grub /dev/$_drive ||
grub-install --recheck /dev/$_drive

sed -i --follow-symlinks \
            -e '\$aGRUB_DISABLE_OS_PROBER=false' \
            -e "s/.*GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet loglevel=3 acpi_backlight=none\"/" \
            -e "s/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/" \
            -e "s/.*GRUB_SAVE.*/GRUB_SAVEDEFAULT=true/" \
            -e "0,/.*GRUB_DEFAULT=.*/{s/.*GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/}" \
            -e "/.*GRUB_DISABLE_OS_PROBER=.*/d" \
            /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

##----------------------------------------
_line - "$blue" 'Swapfile'
##----------------------------------------

echo
[[ -n "$_swapSize" ]] && {
dd if=/dev/zero of=/swapfile bs=1M count=$_swapSize status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo -e "\n\n/swapfile     none     swap     defaults    0 0" >> /etc/fstab
}

##----------------------------------------
_line - "$blue" 'Root Password'
##----------------------------------------

printf "$_rootPass\n$_rootPass\n" | passwd

##----------------------------------------
_line - "$blue" 'Add User'
##----------------------------------------

[[ -n "$_userName" ]] && {
useradd -mG wheel $_userName
printf "$_userPass\n$_userPass\n" | passwd $_userName

## artix
[[ $_distro = artix ]] && usermod -aG audio,input,storage,video $_userName
}

##----------------------------------------
_line - "$blue" 'Doas Config'
##----------------------------------------

command -v doas >dev/null &&
   echo -e "permit nopass :root\n\npermit persist :wheel" > /etc/doas.conf &&
      echo -e "--------|Done" ||
         echo -e "--------|Doas not installed, skipped.\n"

exit
##=========================================================================================
EOF

chmod +x /mnt/root/install.sh
$CHROOT-chroot /mnt /root/install.sh
rm -rf /mnt/root/install.sh

##FINISH-------------------------------------------------------------------------------
_line = Boldblue FINISH

read -r -p "Reboot now ?   [Y/n]" yn
  case $yn in
     [nN]*) break
            exit
            ;;
         *) umount -R /mnt
            echo -e "You can replace bootable drive after reboot\nand ENJOY..!\n\nReboot in seconds."
            sleep 5
            reboot
            ;;
  esac
}

##=======================================================================================

clear

   _about
   _inet
   _distro_select
   _partition
   _device_info
   _add_user
   _pkg_select
   _mount
   sh -c "$(printf "$_iLoveCandy")"
   _install
   _config

##===========================================END======================================#
