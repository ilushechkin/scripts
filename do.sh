#!/bin/bash

echo -e "Acquire::ForceIPv4 \"true\";" > /etc/apt/apt.conf.d/99force-ipv4
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade

###

echo -n "Username: "
read USERNAME

if [ -z "$USERNAME" ]
then
    echo "Username must not be empty"
    exit
fi

echo -n "SSH Port [default=22]: "
read PORT

if [ -z "$PORT" ]
then
    PORT='22'
fi

useradd -s /bin/bash -m $USERNAME
passwd $USERNAME
usermod -a -G sudo,adm $USERNAME

su $USERNAME -c "mkdir /home/$USERNAME/.ssh"
cp ~/.ssh/authorized_keys /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod -R 700 /home/$USERNAME/.ssh

sed -e "s/#\?force_color_prompt=.*/force_color_prompt=yes/g" -i /home/$USERNAME/.bashrc

###

apt-get -y install unzip exim4-daemon-light mailutils mutt unattended-upgrades update-notifier-common fail2ban logwatch curl multitail landscape-common
dpkg-reconfigure tzdata
dpkg-reconfigure exim4-config
sed -e "s/#\?root: .*/root: $USERNAME/g" -i /etc/aliases
dpkg-reconfigure --priority=low unattended-upgrades
echo -e "\nUnattended-Upgrade::Mail \"$USERNAME\";" >> /etc/apt/apt.conf.d/50unattended-upgrades
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
service fail2ban restart
mkdir /var/cache/logwatch
cp /usr/share/logwatch/default.conf/logwatch.conf /etc/logwatch/conf/
sed -e "s/#\?MailTo = .*/MailTo = $USERNAME/g" -i /etc/logwatch/conf/logwatch.conf
echo -e "1 Time\(s\)" > /etc/logwatch/conf/ignore.conf

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.sav
sed -e "s/#\?Port .*/Port $PORT/g" -i /etc/ssh/sshd_config
sed -e "s/#\?LoginGraceTime .*/LoginGraceTime 10/g" -i /etc/ssh/sshd_config
sed -e "s/#\?RSAAuthentication .*/RSAAuthentication yes/g" -i /etc/ssh/sshd_config
sed -e "s/#\?PubkeyAuthentication .*/PubkeyAuthentication yes/g" -i /etc/ssh/sshd_config
sed -e "s/#\?PermitRootLogin .*/PermitRootLogin no/g" -i /etc/ssh/sshd_config
sed -e "s/#\?PasswordAuthentication .*/PasswordAuthentication no/g" -i /etc/ssh/sshd_config
echo -e "\nMaxAuthTries 3\nUseDNS no\nAllowUsers $USERNAME" >> /etc/ssh/sshd_config
service ssh restart

fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo -e "/swapfile   none    swap    sw    0   0" >> /etc/fstab

apt-get install git-core build-essential libtool autotools-dev autoconf pkg-config libssl-dev libboost-all-dev
