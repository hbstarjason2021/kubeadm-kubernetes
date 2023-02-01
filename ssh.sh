#!/bin/bash
SERVERS="172.30.1.2 172.30.2.2"
PASSWD="123456"

function sshcopyid
{
    expect -c "
        set timeout -1;
        spawn ssh-copy-id $1;
        expect {
            \"yes/no\" { send \"yes\r\" ;exp_contine; }
            \"password:\" { send \"$PASSWD\r\";exp_continue; }
        };
        expect eof;
    "
}

for server in $SERVERS
do
    sshcopyid $server

done


###### ssh-keygen -t rsa
###### ssh-keygen -f ~/.ssh/id_rsa -P '' -q
###### ssh-copy-id [remotehost]
###### ssh-copy-id -i .ssh/id_rsa.pub -p 22 root@172.30.2.2
