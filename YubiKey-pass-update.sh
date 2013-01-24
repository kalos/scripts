#!/bin/bash

# simple script to update my yubikey and ecryptfs password
# http://nerdrug.org/blog/gestione-delle-credenziali/

YBAK="/root/yubikey"

TO="kalos.nerd@gmail.com"
SUBJ="[backup]: yubikey"
MSMTP_ARGS="-C $HOME/.mail/.msmtprc"

# insert old password
read -s -p "current password (with static yubikey): " old_pass
echo
read -s -p "current password (again): " old_pass2
echo

if [[ "$old_pass" = "$old_pass2" ]]; then
  unset old_pass2
else
  echo "current password not match"
  exit
fi

echo
echo "save static yubikey in $YBAK to prevent key loss along of system crash"
sudo su -c "echo $old_pass | tail -c 44 > $YBAK"

echo
echo "reinizialize yubikey static password"
echo
sudo ykpersonalize -2 -ofixed=ichrigifhv -osend-ref -o-man-update -y

# decrypt ecryptfs mount passphrase
mount_pass=$(echo -E "$old_pass" | ecryptfs-unwrap-passphrase ~/.ecryptfs/wrapped-passphrase -)

echo
echo "save mount pass in $YBAK"
sudo su -c "echo $mount_pass >> $YBAK"

# insert new password
echo
read -s -p "new password (with static yubikey): " new_pass
echo
read -s -p "new password (again): " new_pass2
echo

if [[ "$new_pass" = "$new_pass2" ]]; then
  unset new_pass2
else
  echo "new password not match"
  exit
fi

echo
echo "change unix user password"
sudo su -c "echo $USER:$new_pass | chpasswd"

# crypt ecryptfs mount passphrase
printf "%s\n%s" "$mount_pass" "$new_pass" | ecryptfs-wrap-passphrase ~/.ecryptfs/wrapped-passphrase > /dev/null

# backup passwords
echo
echo -e "passwords to backup:\n"
echo "---"
echo -e "old: $old_pass\nnew: $new_pass\nmount: $mount_pass"
echo "---"
echo

echo -e "crypt and send backup...\n"

pass_crypt=$(echo -e "old: $old_pass\nnew: $new_pass\nmount: $mount_pass" | gpg --symmetric -a)
headers=$(echo -e "To: $TO\nSubject: $SUBJ")

echo -e "$headers\n\r$pass_crypt" \
  | msmtp $MSMTP_ARGS $TO \
  && echo "email sent!" \
  && sudo shred -un 4 $YBAK

# unset all vars
unset old_pass mount_pass new_pass pass_crypt headers
