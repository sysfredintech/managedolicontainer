### FOR TESTING PURPOSE

## Script to manage Dolibarr Docker's containers with interactive menu
You can quickly and easily create - backup - restore - duplicate or delete Dolibarr containers

Backup and duplicate functions save documents, customization and modules

## Containers are based on latest official Dolibarr image with mariadb
- Useful for working on different databases and managing several companies or associations
- Usefull for testing modules and customizations

## How to use
- Create an empty directory to download the script
- You must have write permissions in the working directory and must be a member of the docker group (or have root permissions)
- Make the script executable
```
chmod +x managedolicontainer.sh
```
- Don't use to manage existing containers
- All datas will be stored in persistent volumes dolibarr_custom/ dolibarr_documents/ dolibarr_mariadb/ in container's name directory
- All backups and database backups will be reachable in the backup/ and backup_db/ directoies created by the script in the working directory
- To share backups across devices, you should use *grsync* (GUI) or *rsync* (CLI) to synchronize the backup/ and backup_db/ folders

## Possible issues due to lack of testing
- Dolibarr image version upgraded since backup when restore or duplicate
- Dolibarr image version upgraded since container is running when duplicate from a running conatiner
