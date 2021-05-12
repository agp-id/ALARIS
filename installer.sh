#!/usr/bin/env sh
##Run as root-------------------------------------------------------------------------
[[ "$(id -u)" != 0 ]] && echo "Please run as root !" && exit

## Force exit
trap exit SIGINT
##------------------------------------------------------------------------------------
#                                   VARIABLE
##------------------------------------------------------------------------------------
#packages
    _base="base"
    _baseDevel="binutils bison fakeroot gcc m4 make patch pkgconf"
    _firmware="linux-zen linux-zen-headers linux-firmware"
    _bootloader="grub"
    ##efi##
    [[ -d /sys/firmware/efi ]] && {
      _efi=1
      _bootloader="$_bootloader efibootmgr"
    }
    _grubOpt="os-prober ntfs-3g"
    _initArtix="runit elogind-runit"
    _networkArtix="iwd-runit dhcpcd-runit"
    _network="iwd dhcpcd"
    _driver="intel-ucode broadcom-wl-dkms"
    _utility="reflector neovim git opendoas"
    #config
    _timeZone="/usr/share/zoneinfo/Asia/Jakarta"
    _locale="en_US.UTF-8"

##------------------------------------------------------------------------------------
#                                   OS SLEECT
##------------------------------------------------------------------------------------
_distro_select (){
   _line "Select Distro"
   printf "[${r}a${n}]rch\n[${g}A${n}]rtix\n---------\n${y}Install         :${n}"
   read -e -p " " -i "A" _distro
      case $_distro in
         a*) _distro="a" ;;
         A*) _distro="A" ;;
         *) clear
            echo "Just match first LETTER, can't you ?"
            _distro_select
            return ;;
      esac
      [[ "$distro" == a ]] &&
         printf "\n${bl}Arch Linux${n} selected, (press any key)" ||
         printf "\n${bl}Artix Linux${n} selected, (press any key)"
   read -n 1 -s -r
   echo
   }

##------------------------------------------------------------------------------------
#                                   PARTITION
##------------------------------------------------------------------------------------
_partition (){
   _line "Select Disk Drive"
   lsblk |egrep "NAME|disk" |sed '1 a\ ---------------' |awk '{print $1,$4}' |
      awk '$1=$1' FS=" " OFS="\t"

   printf "\n${r}[REQUIRED] ${g}DISK Letter?${n} (i.e. $(lsblk |grep "disk" |
      awk '{print $1}' ORS=',' |sed 's/ /,/;s/.$//')): "
   read -r _drive
      [[ "$(lsblk -dno name |grep -x "$_drive")" ]] || {
         clear
         echo  "${r}Drive ${p}$_drive${r} not found, please make sure DRIVE exist in list below!${n}"
         _partition
         return
      }

   _line
   read -n 1 -s -r -p "Please create/check your partition!  (press any key)"
   cfdisk /dev/"$_drive"

   clear
   _line "Select Partitions"
  lsblk |egrep "NAME|$_drive.*part" |
     sed "s/.*$_drive/$_drive/;1 a\ --------------------------" |
     awk '{print $1,$4,$7}' FS=" " OFS="\t"

   printf "\n\n${r}[REQUIRED] ${c}ROOT partition${n} (i.e. $_drive<DIGIT>): $_drive"
   read -r _root
         [[ -n "$_root" ]] && [[ "$(lsblk |egrep "$_drive$_root.*part")" ]] || {
            clear
            echo "${r}Partition ${p}/dev/$_drive$_root${r} not found!, please check again!${n}"
            _partition
            return
         }

   if [[ "$_efi" == 1 ]]; then
      read -r -p "${r}[REQUIRED] ${y}BOOT partition${n} (i.e. $_drive<DIGIT>): $_drive" _boot
         [[ -z "$_boot" ]] && {
            clear
            echo "${r}I think your device is ${p}UEFI${r}, please create/select boot partition!${n}"
            _partition
            return
         }
   else
      read -r -p "${p}[OPTIONAL] ${c}BOOT partition${n} (i.e. $_drive<DIGIT>): $_drive" _boot
   fi


         if [[ -z "$_boot" ]]; then
            :
         elif
            [[ ! "$(lsblk |egrep "$_drive$_boot.*part")" ]]; then
               clear
               echo "${r}Partition ${p}/dev/$_drive$_boot${r} not found!, please check again!${n}"
               _partition
               return
         elif [[ "$_drive$_root" == "$_drive$_boot" ]]; then
            clear
            echo "${p}/dev/$_drive$_root${r} is root partition, select other!${n}"
            _partition
            return
         fi

   read -r -p "${p}[OPTIONAL] ${c}HOME partition${n} (i.e. $_drive<DIGIT>): $_drive" _home

         if [[ -z "$_home" ]]; then
            :
         elif
            [[ ! "$(lsblk |egrep "$_drive$_home.*part")" ]]; then
               clear
               echo "${r}Partition ${p}/dev/$_drive$_home${r} not found!, please check again!${n}"
               _partition
               return
         elif
            [[ "$_drive$_home" == "$_drive$_root" ]]; then
            clear
            echo "${p}/dev/$_drive$_root${r} is root partition, select other!${n}"
            _partition
            return
         elif
            [[ "$_drive$_home" == "$_drive$_boot" ]]; then
            clear
            echo "${p}/dev/$_drive$_boot${r} is boot partition, select other!${n}"
            _partition
            return
         fi

   _swap_file
}

_swap_file (){
   echo -e "\n${p}[OPTIONAL] ${c}Enable swapfile${n}, min 512MB."
   read -p "Insert size (MB): " _swapSize

      if [[ -z "$_swapSize" ]]; then
         return
      elif ! [[ $_swapSize =~ ^[-+]?[0-9]+$ ]]; then
         clear
         echo "${r}Sorry digits only${n}"
         _swap_file
      elif (( $_swapSize < 512 )); then
         clear
         echo "${r}Minimal size 512MB${n}"
         _swap_file
      fi
}

##------------------------------------------------------------------------------------
#                                DEVICE & USER
##------------------------------------------------------------------------------------
_device_info (){
   _line "Device & User"
   _host_name
}

_host_name() {
   read -p "${r}[REQUIRED] ${c}Hostname     :${n} " _hostName
      [[ -z "$_hostName" ]] && {
         echo "Sorry can't empty!"
         _host_name
         return
      } || _root_pass
}

_root_pass() {
   IFS= read -p "${r}[REQUIRED] ${c}Root Password:${n} " _rootPass
      [[ -z "$_rootPass" ]] && {
         echo "Sorry can't empty!"
         _root_pass
      }
}

_add_user (){
   echo
   read -p "${p}[OPTIONAL] ${c}Add User     : ${n}" _userName
   [[ -n "$_userName" ]] && _user_pass
}

_user_pass() {
   IFS= read -p "${r}[REQUIRED] ${c}User Password: ${n}" _userPass
   [[ -z "$_userPass" ]] && {
         echo "Sorry can't empty!"
         _user_pass
         }
}

##------------------------------------------------------------------------------------
#                                Base, Firwmware, and Packages
##------------------------------------------------------------------------------------
_pkg_select() {
   _line 'Packages Selection'
    read -e -p "${y}Base [devel]    : ${n}$_base " -i "$_baseDevel" _baseDevel
    read -e -p "${y}Linux [firmware]: ${n}" -i "$_firmware" _firmware
    [[ -z "$_firmware" ]] && _firmware="linux linux-firmware"

    if [[ "$_distro" == a ]]; then
       #arch#
        read -e -p "${y}Network         : ${n}$_network" _service
        _service="$_network $_service"
     else
       #artix#
        read -e -p "${y}Network         : ${n}$_networkArtix" _service
        _service="$_initArtix $_networkArtix $_service"
    fi

    read -e -p "${y}Bootloader      : ${n}$_bootloader " -i "$_grubOpt" _bootOpt
    read -e -p "${y}Driver          : ${n}" -i "$_driver" _driver
    read -e -p "${y}Other packages  : ${n}" -i "$_utility" _utility
   _line "Locale Config"
    read -e -p "${p}Local Time      : ${n}" -i "$_timeZone" _timeZone

    read -e -p "${p}Locale          : ${n}" -i "$_locale" _locale

    _pkgs="$_base $_baseDevel $_firmware $_service $_bootloader $_bootOpt $_driver $_utility "

}

##------------------------------------------------------------------------------------
#                                   Mount Partition
##------------------------------------------------------------------------------------
_mount (){
   _line "Mounting Partitions"
   umount -R /mnt /mnt/boot /mnt/boot/efi /mnt/home

   : | mkfs.ext4 /dev/"$_drive$_root"
   mount /dev/"$_drive$_root" /mnt

   if [[ "$_efi" == 1 ]]; then
      : | mkfs.fat -F32 /dev/"$_drive$_boot"
      mkdir -p /mnt/boot/efi
      mount /dev/"$_drive$_boot" /mnt/boot/efi
   elif [[ -n "$_boot" ]]; then
      : | mkfs.ext4 /dev/"$_drive$_boot"
      mkdir /mnt/boot
      mount /dev/"$_drive$_boot" /mnt/boot
   fi

   [[ -n "$_home" ]] && {
      : | mkfs.ext4 /dev/"$_drive$_home"
      mkdir /mnt/home
      mount /dev/"$_drive$_home" /mnt/home
      }

}

##------------------------------------------------------------------------------------
#                                   Installation
##------------------------------------------------------------------------------------
_install() {
   _line "Starting Installation"
   echo $_pkgs | grep " reflector " &>/dev/null || {
      echo "'reflector' will be install to update mirror arch. You can uninstall later."
      read -n 1 -s -r -p "(press any key)"
      printf "\n\n"
      _pkgs="$_pkgs reflector"
   }
   _install2 || {
      read -p "Installation not completed, try again ?   [Y/n] " _ins
      case $_ins in
         [nN]* )
            exit 1 ;;
         * )
            _install2
            return ;;
      esac
   }
}
_install2() {
   if [[ "$_distro" == a ]]; then
      ##arch##
      timedatectl set-ntp true
      pacstrap /mnt --needed --noconfirm $_pkgs
   else
      ##artix##
      basestrap /mnt --needed --noconfirm $_pkgs
   fi
}

##------------------------------------------------------------------------------------
#                                 Essential Configurations
##------------------------------------------------------------------------------------
_config() {
   _line "Essential Configurations"
   [[ "$_distro" == a ]] && {
      ##arch##
      genfstab -U /mnt > /mnt/etc/fstab
      CHROOT=arch
   } || {
      ##artix##
      fstabgen -U /mnt > /mnt/etc/fstab
      CHROOT=artix
      }

cat << EOF | $CHROOT-chroot /mnt
#---------------------------------------
#              Time Zone
#---------------------------------------
ln -sf $_timeZone /etc/localtime
hwclock --systohc

#---------------------------------------
#              Localization
#---------------------------------------
echo "$_locale UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$_locale" > /etc/locale.conf

#---------------------------------------
#   Pacman I Love Candy & mirror arch
#---------------------------------------
${_iLoveCandy}

### Reflector update mirror arch
[[ "$_distro" == a ]] &&
##arch##
reflector --verbose --latest 5 --protocol http,https --sort rate \
--save /etc/pacman.d/mirrorlist ||
##artix##
reflector --verbose --latest 5 --protocol http,https --sort rate \
--save /etc/pacman.d/mirrorlist-arch

#---------------------------------------
#              Network Setup
#---------------------------------------
echo "$_hostName" > /etc/hostname
cat << eof1 | tee /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $_host_Name.localdomain     $_hostName
eof1

#---------------------------------------
#              Wifi tools
#---------------------------------------
if
[[ "$_distro" == a ]]; then
##arch##
systemctl enable iwd dhcpcd
else
##artix##
ln -s /etc/runit/sv/iwd /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default/
fi

mkdir /etc/iwd
echo -e "[General]\nEnableNetworkConfiguration=true" | tee /etc/iwd/main.conf

#---------------------------------------
#              Bootloader
#---------------------------------------
[[ "$_efi" == 1 ]] &&
grub-install --target=x86_64-efi --efi-directory=/boot \
--bootloader-id=grub /dev/$_drive ||
grub-install --recheck /dev/$_drive

sed -i \
-e "s/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/" \
-e 's/.*GRUB_SAVE.*/GRUB_SAVEDEFAULT="true"/' \
-e "s/.*GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" \
/etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

#---------------------------------------
#                Swapfile
#---------------------------------------
[[ "$_swapSize" != "" ]] && {
dd if=/dev/zero of=/swapfile bs=1M count=$_swapSize status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo -e "\n\n/swapfile     none     swap     defaults    0 0" >> /etc/fstab
}

#---------------------------------------
#              Root Password
#---------------------------------------
printf "$_rootPass\n$_rootPass\n" | passwd

#---------------------------------------
#           Doas & Add user
#---------------------------------------
command -v doas >dev/null && echo -e "permit nopass :root\n\npermit persist :wheel" > /etc/doas.conf
[[ -n "$_userName" ]] && {
useradd -mG wheel $_userName
printf "$_userPass\n$_userPass\n" | passwd $_userName
##artix##
[[ "$_distro" == A ]] && usermod -aG audio,video $_userName
}

EOF
}

##Decor-------------------------------------------------------------------------------
n=$(tput sgr0) #normal
b=$(tput bold) #bold
r=$(tput setaf 1)
g=$(tput setaf 2)
y=$(tput setaf 3)
bl=$(tput setaf 4)
p=$(tput setaf 5)
c=$(tput setaf 6)

##Pacman:I Love Candy-----------------------------------------------------------------
_iLoveCandy='sed -i --follow-symlinks\
            -e "s/.*Color/Color/"\
            -e "/.*ILove.*/d"\
            -e "/.*Color/a ILoveCandy"\
            -e "s/.*TotalDo.*/TotalDownload/"\
            -e "s/.*VerbosePkgLists/VerbosePkgLists/"\
            /etc/pacman.conf'

##Internet Test-----------------------------------------------------------------------
_try=0
_inet() {
   _line "Internet Connection"
   ping -q -c 1 -W 1 8.8.8.8 &>/dev/null && \
      echo '----|Connected' || {
      echo '----|Disconnected'
      _try=$(($_try+1))
      if [[ $_try == 3 ]]; then
         read -p "Can't ping 8.8.8.8, skip internet check ? [Y/n]    " _c
         case $_c in
            [nN]* )
               _inet
               return ;;
            * )
               _try=0
               return ;;
         esac
      else
        read -n 1 -s -r -p 'Please check your connection! (press any key)'
         _inet
      fi
   }
   sleep 1
}

##Title and line----------------------------------------------------------------------
# _line 'TITLE'
# _line
_line(){
   [ -n "$1" ] && {
      printf "\n%-${COLUMNS}s" | sed 's/ /=/g'
      _title="########/    $b$bl$1$n    /########"
      printf "%-$(( ($COLUMNS-${#_title}+13)/2 ))s"; echo "$_title"
      printf "%-${COLUMNS}s" | sed 's/ /-/g'
   } ||    printf "\n%-${COLUMNS}s" | sed 's/ /-/g'
   echo
}

##Finish-----------------------------------------------------------------------------
_finish() {
   _line FINISH
   read -r -p "Reboot now ?   [Y/n]" _reboot
      case $_reboot in
         [nN]*) exit
                ;;
         *)     umount -R /mnt
                echo -e "You can replace bootable drive after reboot\nand ENJOY..!\n\nReboot in seconds."
                sleep 5
                reboot
                ;;
      esac
}

##About-----------------------------------------------------------------------------
_about(){
   _line "ALARIS: Arch Linux / Artix Runit Installer Script"
   printf "   ${y}Thanks to: ${r}# ${g}${b}ALLAH SWT${n}
              ${r}# ${g}Internet


                ${b}${p}Features : ${n}${r}- ${c}Suport Bios & Uefi(prefered)
                           ${n}${r}- ${c}ext4 and fat32(Uefi boot) filesystem
                           ${n}${r}- ${c}Partition: root, boot(optional BIOS), home(optional)
                           ${n}${r}- ${c}Swapfile enable (Optional)
                           ${n}${r}- ${c}Select your packages, Add/Remove (except main packages)
                           ${n}${r}- ${c}Add user (Optional)


   ${b}${y}Write by    : ${n}Agung p
   ${b}${y}Github      : ${n}https://github.com/agp-id/ALARIS

   ${b}${p}Create date : ${n}19-04-2021
   ${b}${p}Last Update : ${n}${g}12-05-2021
   \n\n"
   read -n 1 -s -r -p "${n}Press any key "
}
#===================================================================================#
##Start here##

clear
_about
_distro_select
_inet
_partition
_device_info
_add_user
_pkg_select
_mount
sh -c "$(printf "$_iLoveCandy")"
_install
_config
_finish

#===========================================END======================================#
