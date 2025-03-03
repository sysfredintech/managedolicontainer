#!/bin/bash
#
clear
today=$(date +%d%m%Y%H%M)
curentuser=$(id -un)
userid=$(id -u)
curent_dir=$(pwd)
# checking parameters
if [[ ! $(which docker | grep "/usr/bin/docker") =~ "/usr/bin/docker" ]]; then
    echo -e "\e[31mDocker is not installed, cannot continue\e[0m"
    exit 1
elif [[ ! $(docker compose version) =~ "Docker Compose" ]]; then
    echo -e "\e[31mDocker Compose is not installed, cannot continue\e[0m"
    exit 1
elif [[ ! $(which rsync | grep "/usr/bin/rsync") =~ "/usr/bin/rsync" ]]; then
    echo -e "\e[31mRsync is not installed, cannot continue\e[0m"
    exit 1
elif [[ ! -w ./ ]]; then
    echo -e "\e[31mYou do not have write permissions in the working directory, cannot continue\e[0m"
    exit 1
elif [[ ! $(id -nG "$curentuser" | grep docker) =~ "docker" && ! $(id -un) == "root" ]]; then
    echo -e "\e[31mYou are not a member of the docker group and do not have root permissions, cannot continue\e[0m"
    exit 1
elif [[ ! -d $curent_dir/backup ]]; then
    mkdir $curent_dir/backup
elif [[ ! -d $curent_dir/backup_db ]]; then
    mkdir $curent_dir/backup_db
fi
backup_dir=$(pwd)/backup
backup_db_dir=$(pwd)/backup_db
###########################################################################################################################################################
list_container()
{
clear
IFS='\n' ctlist=$(ls -lGd */ | awk '{print $8}' | cut -d '/' -f1  | grep -v "backup")
if [[ -z "$ctlist" ]]; then
    echo -e "\e[31mNo available Dolibarr container\e[0m"
    ct_manager
else
    echo -e "\e[32mAvailable Dolibarr containers: \n\e[0m"
    echo -e "$ctlist\n"
fi
}
changeport()
{
portnumber=8080
buzyport=$(ss -pant | awk '{print $4}' | awk '{print $2}' FS=':')
while :
do
    if echo "$buzyport" | grep -qw "$portnumber"; then
        portnumber=$(($portnumber+1))
    else
        break
    fi
done
}
result ()
{
    if [[ $? == 0 ]]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}
waitctisready ()
{
    echo -e "\e[33mWaiting for the container to be ready...\e[0m"
    while :
    do
        if [[ $(docker compose -f "$pathtoct/docker-compose.yml" logs) =~ "You can connect to your Dolibarr web application with" ]]; then
            break
        else
            sleep 5
        fi
    done
}
###########################################################################################################################################################
config_container ()
{
    echo -e "\e[33mDONT'T LEFT BLANK AND DON'T USE ANY SPECIAL CHARACTERS\e[0m"
while :
do
echo "Enter a password for database root access: "
read -s sqlrootpasswdtmp
echo "Confirm password for database root access: "
read -s sqlrootpasswd
if [[ "$sqlrootpasswdtmp" != "$sqlrootpasswd" ]]; then
	echo -e "\e[31mIncorrect, please retry\e[0m"
	continue
else
	break
fi
done
read -p "Choose a name for database: " dbname
read -p "Choose a name for database user: " dbuser
while :
do
echo "Enter a password for database user access: "
read -s sqluserpasswdtmp
echo "Confirm password for database user access: "
read -s sqluserpasswd
if [[ "$sqluserpasswdtmp" != "$sqluserpasswd" ]]; then
	echo -e "\e[31mIncorrect, please retry\e[0m"
	continue
else
	break
fi
done
read -p "Choose a name for Dolibarr administrator: " doliadmin
while :
do
echo "Enter a password for Dolibarr administrator: "
read -s doliadminpasswdtmp
echo "Confirm password for Dolibarr administrator: "
read -s doliadminpasswd
if [[ "$doliadminpasswdtmp" != "$doliadminpasswd" ]]; then
	echo -e "\e[31mIncorrect, please retry\e[0m"
	continue
else
	break
fi
done
read -p "Enter your company's name: " companyname
}
creation ()
{
    config_container
    changeport
    pathtoct="$(pwd)/$containername"
    mkdir -p "$pathtoct/dolibarr_custom" \
              "$pathtoct/dolibarr_documents" \
              "$pathtoct/dolibarr_mariadb"
    touch "$pathtoct/docker-compose.yml"
    cat <<EOF > "$pathtoct/docker-compose.yml"
services:
    mariadb:
        image: mariadb:latest
        container_name: '$containername-mariadb'
        user: $userid:$userid
        environment:
            MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD:-$sqlrootpasswd}
            MYSQL_DATABASE: \${MYSQL_DATABASE:-$dbname}
            MYSQL_USER: \${MYSQL_USER:-$dbuser}
            MYSQL_PASSWORD: \${MYSQL_PASSWORD:-$sqluserpasswd}
        volumes:
            - $pathtoct/dolibarr_mariadb:/var/lib/mysql
            - $backup_db_dir:/backup_db
        restart: always

    web:
        image: dolibarr/dolibarr:latest
        container_name: '$containername-web'
        environment:
            WWW_USER_ID: \${WWW_USER_ID:-$userid}
            WWW_GROUP_ID: \${WWW_GROUP_ID:-$userid}
            DOLI_DB_HOST: \${DOLI_DB_HOST:-$containername-mariadb}
            DOLI_DB_NAME: \${DOLI_DB_NAME:-$dbname}
            DOLI_DB_USER: \${DOLI_DB_USER:-$dbuser}
            DOLI_DB_PASSWORD: \${DOLI_DB_PASSWORD:-$sqluserpasswd}
            DOLI_URL_ROOT: "\${DOLI_URL_ROOT:-http://0.0.0.0}"
            DOLI_ADMIN_LOGIN: "\${DOLI_ADMIN_LOGIN:-$doliadmin}"
            DOLI_ADMIN_PASSWORD: "\${DOLI_ADMIN_PASSWORD:-$doliadminpasswd}"
            DOLI_CRON: \${DOLI_CRON:-0}
            DOLI_INIT_DEMO: \${DOLI_INIT_DEMO:-0}
            DOLI_COMPANY_NAME: \${DOLI_COMPANY_NAME:-$companyname}
        ports:
            - "$portnumber:80"
        links:
            - mariadb
        volumes:
            - $pathtoct/dolibarr_documents:/var/www/documents
            - $pathtoct/dolibarr_custom:/var/www/html/custom
        restart: always
EOF
    docker compose -f "$pathtoct/docker-compose.yml" up -d
    waitctisready
    result
    echo -e "Your new container will be accessible at http://localhost:$portnumber"
    echo -e "User: '$doliadmin'\nPassword: '$doliadminpasswd'"
    ct_manager
}
check_creation ()
{
    echo -e "\e[33mPress Enter to go back to the main menu\e[0m"
    read -p "Choose the container name (must not contain special characters or spaces): " containername
    if [[ -z "$containername" ]]; then
        clear
        ct_manager
    fi
    pathtoct="$(pwd)/$containername"
    while [[ -d "$pathtoct" ]]; do
        echo -e "\e[1;31;1;47mWarning: This container already exists, do you want to replace it?\nWarning: All its data will be deleted and this action is irreversible\e[0m"
        read -p "(y)yes (n)no: " confirmerase
        if [[ $confirmerase == [yY] ]]; then
            docker compose -f "$pathtoct/docker-compose.yml" down
            sleep 5
            rm -rf "$pathtoct/"
            break
        elif [[ $confirmerase == [nN] ]]; then
            ct_manager
            break
        else
            echo -e "Invalid parameter"
        fi
    done
    result
    creation
}
###########################################################################################################################################################
backup_ct ()
{
list_container
while :
do
echo -e "\e[33mPress Enter to go back to the main menu\e[0m"
read -p "Choose the target (must not contain special characters or spaces): " target
if [[ -z "$target" ]]; then
    clear
    ct_manager
elif [[ ! -d "$curent_dir/$target" ]]; then
    echo "The target does not exist"
else
    tar --exclude='dolibarr_mariadb/*' -cJf "$backup_dir/$target--$today.tar.xz" "$curent_dir/$target/"
    docker exec $target-mariadb sh -c 'mariadb-dump --all-databases -u root -p"$MYSQL_ROOT_PASSWORD" > backup_db/tmp-db.sql'
    mv $backup_db_dir/tmp-db.sql $backup_db_dir/$target--$today--db.sql
    break
fi
done
result
ct_manager  
}
#
input-choice ()
{
IFS='\n' listtar=$(ls -lG $backup_dir/ | grep -i ".tar.xz" | awk '{print $NF}')
if [[ -z "$listtar" ]]; then
    echo -e "\e[31mNo available backup\e[0m"
    ct_manager
else
    echo -e "$listtar"
    echo -e "\e[33mPress Enter to go back to the main menu\e[0m"
    read -p "Choose the source: " tarfile
fi
result
}
###########################################################################################################################################################
ctrestore()
{
input-choice
if [[ ! -e "$backup_dir/$tarfile" ]]; then
    echo -e "\e[31mTarget doesn't exist\e[0m"
    ct_manager
elif [[ -z "$tarfile" ]]; then
    clear
    ct_manager
fi
repocontainer=$(echo "$tarfile" | awk '{print $1}' FS="--")
pathtoct=$(pwd)/$repocontainer
    if [[ -d $pathtoct ]]; then
    echo -e "\e[1;31;1;47mWarning: This container already exists and will be replaced. Continue?\nWarning: All its data will be deleted and this action is irreversible\e[0m"
    read -p "(y)yes (n)no: " answer
        if [[ $answer == [yY] ]]; then
        docker compose -f $pathtoct/docker-compose.yml down
        sleep 5
        rm -rf $pathtoct
        tar xJf $backup_dir/$tarfile -C /
        result
        else
        ct_manager
        fi
    else 
        tar xJf $backup_dir/$tarfile -C /
        result
    fi
    result
    changeport
    sed -E -i "33s/[0-9]+:/$portnumber:/" $pathtoct/docker-compose.yml
    docker compose -f $pathtoct/docker-compose.yml up -d
    waitctisready
    result
    backupfile=$(echo $tarfile | cut -d '.' -f1)
    cp $backup_db_dir/$backupfile--db.sql $backup_db_dir/db_backup_tmp.sql
    docker exec $repocontainer-mariadb sh -c 'mariadb -h 127.0.0.1 -P 3306 --protocol=tcp -u root -p"$MYSQL_ROOT_PASSWORD" < /backup_db/db_backup_tmp.sql'
    ctpath=$(docker ps -n1 | awk '{print $11}' | awk '{print $1}' FS="-" | sed s/0.0.0.0/localhost/g)
    echo -e "Your container will be accessible at: "$ctpath""
ct_manager
}
###########################################################################################################################################################
duplicate ()
{
while :
do
echo -e "\nFrom a backup = 1\nFrom a container = 2\nPress Enter to go back to the main menu"
read duplicatechoice
if [[ "$duplicatechoice" == "1" ]]; then
    duplicfrombackup
    break
elif [[ "$duplicatechoice" == "2" ]]; then
    duplicatefromcontainer
    break
elif [[ -z "$duplicatechoice" ]]; then
    clear
    ct_manager
    break
else
    echo -e "\e[31mInvalid parameter\e[0m"
fi
done
result
}
duplicfrombackup ()
{
input-choice
repocontainer=$(echo "$tarfile" | awk '{print $1}' FS="--")
read -p "Choose a name for the new container (must not contain special characters or spaces): " newcontainer
pathtoct=$(pwd)/$newcontainer
    if [[ -d $pathtoct ]]; then
    echo -e "\e[1;31;1;47mWarning: This container already exists and will be replaced. Continue?\nWarning: All its data will be deleted and this action is irreversible\e[0m"
    read -p "(y)yes (n)no: " answer
        if [[ $answer == [yY] ]]; then
            docker compose -f $pathtoct/docker-compose.yml down
            sleep 5
            rm -rf $pathtoct
            startduplicfrombackup
        else
            ct_manager
        fi
    else 
        startduplicfrombackup
    fi
    result
}
startduplicfrombackup ()
{
mkdir -p $pathtoct
tar -xJf $backup_dir/$tarfile -C $pathtoct --strip-components=3
result
sed -i "s|\$curent_dir[^/]*\/|\$pathtoct\/|g" $pathtoct/docker-compose.yml
changeport
sed -E -i "33s|[0-9]+:|$portnumber:|" "$pathtoct/docker-compose.yml"
sed -i "s/[0-Z]\+-mariadb/$newcontainer-mariadb/g" $pathtoct/docker-compose.yml
sed -i "s/[0-Z]\+-web/$newcontainer-web/g" $pathtoct/docker-compose.yml
sed -E -i "12s|.*|\ \ \ \ \ \ \ \ \ \ \ \ -\ $pathtoct\/dolibarr_mariadb:\/var\/lib\/mysql|" $pathtoct/docker-compose.yml
sed -E -i "37s|.*|\ \ \ \ \ \ \ \ \ \ \ \ -\ $pathtoct\/dolibarr_documents:\/var\/www\/documents|" $pathtoct/docker-compose.yml
sed -E -i "38s|.*|\ \ \ \ \ \ \ \ \ \ \ \ -\ $pathtoct\/dolibarr_custom:\/var\/www\/html\/custom|" $pathtoct/docker-compose.yml
docker compose -f $pathtoct/docker-compose.yml up -d
result
waitctisready
backupfile=$(echo $tarfile | cut -d '.' -f1)
cp $backup_db_dir/$backupfile--db.sql $backup_db_dir/db_backup_tmp.sql
docker exec $newcontainer-mariadb sh -c 'mariadb -h 127.0.0.1 -P 3306 --protocol=tcp -u root -p"$MYSQL_ROOT_PASSWORD" < /backup_db/db_backup_tmp.sql'
ctpath=$(docker ps -n1 | awk '{print $11}' | awk '{print $1}' FS="-" | sed s/0.0.0.0/localhost/g)
echo -e "Your container will be accessible at: "$ctpath""
ct_manager
}
duplicatefromcontainer ()
{
IFS='\n' ctlist=$(ls -lG ./ | awk '{print $8}'  | grep -v "backup")
echo -e "$ctlist"
while :
do
read -p "Choose the source: " source
if [[ ! -d "$curent_dir/$source" ]]; then
    echo "The source does not exist"
else
    read -p "Choose a name for the new container (must not contain special characters): " newcontainer
    pathtoct="$(pwd)/$newcontainer"
    if [[ -d "$pathtoct" ]]; then
        echo -e "\e[1;31;1;47mWarning: This container already exists and will be replaced. Continue?\nWarning: All its data will be deleted and this action is irreversible\e[0m"
        read -p "(y)yes (n)no: " answer
        if [[ $answer == [yY] ]]; then
            docker compose -f $pathtoct/docker-compose.yml down
            sleep 5
            rm -rf $pathtoct
            startduplicfromcontainer
            break
        else
            ct_manager
        fi
    else
        startduplicfromcontainer
        break
    fi
fi
done
}
startduplicfromcontainer ()
{
docker exec $source-mariadb sh -c 'mariadb-dump --all-databases -u root -p"$MYSQL_ROOT_PASSWORD" > backup_db/tmp-db.sql'
mkdir $pathtoct
rsync -arh --exclude '$curent_dir/$source/dolibarr_mariadb/*' "$curent_dir/$source/" "$pathtoct"
result
sed -i "s|\$curent_dir[^/]*\/|\$pathtoct\/|g" $pathtoct/docker-compose.yml
changeport
sed -E -i "33s|[0-9]+:|$portnumber:|" "$pathtoct/docker-compose.yml"
sed -i "s/[0-Z]\+-mariadb/$newcontainer-mariadb/g" $pathtoct/docker-compose.yml
sed -i "s/[0-Z]\+-web/$newcontainer-web/g" $pathtoct/docker-compose.yml
sed -E -i "12s|.*|\ \ \ \ \ \ \ \ \ \ \ \ -\ $pathtoct\/dolibarr_mariadb:\/var\/lib\/mysql|" $pathtoct/docker-compose.yml
sed -E -i "37s|.*|\ \ \ \ \ \ \ \ \ \ \ \ -\ $pathtoct\/dolibarr_documents:\/var\/www\/documents|" $pathtoct/docker-compose.yml
sed -E -i "38s|.*|\ \ \ \ \ \ \ \ \ \ \ \ -\ $pathtoct\/dolibarr_custom:\/var\/www\/html\/custom|" $pathtoct/docker-compose.yml
docker compose -f $pathtoct/docker-compose.yml up -d
result
waitctisready
docker exec $newcontainer-mariadb sh -c 'mariadb -h 127.0.0.1 -P 3306 --protocol=tcp -u root -p"$MYSQL_ROOT_PASSWORD" < /backup_db/tmp-db.sql'
ctpath=$(docker ps -n1 | awk '{print $11}' | awk '{print $1}' FS="-" | sed s/0.0.0.0/localhost/g)
echo -e "Your container will be accessible at: "$ctpath""
ct_manager
}
###########################################################################################################################################################
delete_ct ()
{
IFS='\n' ctlist=$(ls -lGd */ | awk '{print $8}' | cut -d '/' -f1 | grep -v "backup")
echo -e "\e[32mAvailable Dolibarr containers: \n\e[0m"
echo -e "$ctlist"
while :
do
echo -e "\e[33mPress Enter to go back to the main menu\e[0m"
read -p "Choose the target: " target
if [[ ! -d "./$target" ]]; then
    echo -e "\e[31mThe target does not exist\e[0m"
    ct_manager
elif [[ -z "$target" ]]; then
    clear
    ct_manager
else
    echo -e "\e[1;31;1;47mWarning: This container already exists, do you want to replace it?\nWarning: All its data will be deleted and this action is irreversible\e[0m"
    read -p "(y)yes (n)no: " answer
    if [[ $answer == [yY] ]]; then
        docker compose -f $target/docker-compose.yml down
        rm -rf $target/
        echo -e "Container $target deleted successfully"
        result
        ct_manager
    else
        clear
        ct_manager
    fi
fi
done
}
###########################################################################################################################################################
ct_manager ()
{
while :
do
echo -e "\e[1;33mDOLIBARR CONTAINER MANAGEMENT TOOLS\n\e[0m"
echo -e "\e[33mThis script allows you to manage ONLY Dolibarr containers that have been created with\e[0m"
echo -e "\e[33mIf you try to manage a container that has not been created with this script, it will not work\e[0m"
echo -e "\e[33mYou must have write permissions in the working directory\e[0m"
echo -e "\e[33mYou must be a member of the docker group or have root permissions\n\e[0m"
echo -e "\e[32mYour backup directory is: $backup_dir\e[0m"
echo -e "\e[32mYour database backup directory is: $backup_db_dir\e[0m"
echo -e "\nProgram choice:\n\nl = List container\nb = Backup a container\nr = Restore a container\nc = Create a container\nd = Duplicate a container\nx = Delete a container\nq = Quit\n"
read -p "Choice: " launch_program
if [[ "$launch_program" == [lL] ]]; then
    list_container
    echo -e "\n"
    continue
elif [[ "$launch_program" == [bB] ]]; then
	backup_ct
    break
elif [[ "$launch_program" == [rR] ]]; then
	ctrestore
    break
elif [[ "$launch_program" == [cC] ]]; then
    check_creation
    break
elif [[ "$launch_program" == [dD] ]]; then
    duplicate
    break
elif [[ "$launch_program" == [xX] ]]; then
    delete_ct
    break
elif [[ "$launch_program" == [qQ] ]]; then
    exit 0
    break
else
    clear
	echo -e "Invalid choice, please try again: "
    continue
fi
done
}
ct_manager