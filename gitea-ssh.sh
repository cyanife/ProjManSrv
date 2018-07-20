#!/bin/bash
ROOT_UID=0
SUCCESS=0
PREFIX="no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty"


# Run as root, of course. (this might not be necessary, because we have to run the script somehow with root anyway)
if [ "$UID" -ne "$ROOT_UID" ]; then
	echo "Must be root to run this script."
	exit "$E_NOTROOT"
fi

apt-get update
apt-get install openssh-client -y

# Check if git user already exists.
# if not, then add git user
grep -q git /etc/passwd
if [ $? -eq $SUCCESS ]; then
	echo "User git has already exist."
else
	useradd -d /home/git -s /bin/bash -m git
	echo "User git has been added"
fi
sed -i "s/<GIT_UID_PLACEHOLDER>/$(su git -c 'id -u')/" .env
sed -i "s/<GIT_GID_PLACEHOLDER>/$(su git -c 'id -g')/" .env

su git -c "mkdir -p /home/git/data"
su git -c "mkdir -p /home/git/.ssh"
mkdir -p ./data/gitea/gitea
chown --reference=/home/git -R ./data/gitea/gitea


mkdir -p /app/gitea
cat >/app/gitea/gitea<<'END'
#!/bin/sh

ssh -p 10022 -o StrictHostKeyChecking=no git@127.0.0.1 \
"SSH_ORIGINAL_COMMAND=\"$SSH_ORIGINAL_COMMAND\" $0 $@"
END
chmod 755 /app/gitea/gitea

su git -c "ssh-keygen -t rsa -N '' -f /home/git/.ssh/id_rsa -q"
su git -c "touch /home/git/.ssh/authorized_keys"
su git -c "sed '1s/^/${PREFIX} /' /home/git/.ssh/id_rsa.pub > /home/git/.ssh/authorized_keys"



exit 0
