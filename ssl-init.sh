#!/bin/bash
finished=false
container_name=acme.sh-srv

if [ ! "$(docker ps -q -f name=${container_name})" ]; then
    echo "Please run acme.sh container first!"
    exit 0
fi

while [ ${finished} = false ]
do
    echo "Please input DNSPOD api id: "
    read -r DP_Id
    echo "Please input DNSPOD api token: "
    read -r DP_Key

    if [ -z "$DP_Id" ] || [ -z "$DP_Key" ]; then 
        echo "Invaild input value!"
    else
        echo "Please Confirm your DNSPOD api settings:"
        echo "ID: ${DP_Id}"
        echo "token: ${DP_Key}"

        read -r -p "Are You Sure? [Yes/No/Abort] " input
        case $input in
            [yY][eE][sS]|[yY])
                echo "Continue..."
                finished=true
                ;;

            [nN][oO]|[nN])
                echo "Try again."
                    ;;
            
            [aA][bB][oO][rR][tT]|[aA])
                echo "Aborted."
                exit 0
                    ;;
            *)
            echo "Invalid input..."
            echo "Try again."
            ;;
        esac
    fi
done
docker exec -e DP_Id=${DP_Id}  DP_Key=${DP_Key} ${container_name} --issue -d cyanife.com -d '*.cyanife.com' --dns dns_dp
(crontab -l ; echo "0 4 1 */2 * cd $(dirname $(readlink -f $0)) && docker-compose exec nginx nginx -s reload") | crontab -