# ERP Next Fail Over

### What?
*ERPNextFailOver* is a tool to automate setting up Master / Slave continuous replication for ERPNext.

To be more precise, it sets up MySql/MariaDb replication, but also provides you with tools to help you migrate site specific details, such as `site_config.json`.  You will also find included `handleBackup.sh` and `handleRestore.sh` which take care of backing up an origin site and restoring to a destination having a different site name and URL.

### Why?

You can certainly set up this kind of replication manually, but the docs typically cover many options and alternatives making it time consuming to work through what is appropriate for a single ERPNext installation. This tool will give you a minimum starting configuration, which you can enhance as needed.

For replication to start correctly, you want the master and slave databases to be nearly identical.  In particular they must both manage the same transaction log and the "position tag" in the master's log must be the same as, or ahead of, the slave's log position tag.  Setting up replication requires a sequence of operations that needs to happen correctly or you end up with a setup that seems right but doesn't start.

## How?

To begin with, you should have three independant devices running Ubuntu Linux:

1. Your workstation
2. The master host running ERPNext v13
3. The slave host running ERPNext v13

The entire setup and installation is driven from your workstation according to the variables you set in a shell script file: `envars.sh`.

For our use we have, for example, a master VPS rented in North America and a slave VPS somewhere in Europe.  An equally valid setup would be to use Qemu/KVM, or Virtual Box, etc to create two virtual machines inside your workstation.  The point is to have two distinct target machines each with ERPNext installed in Ubuntu Linux

You will not need to log into either of the other two *unless you use UID/PWD access with SSH*!  These scripts require PKI based SSH access, so you **will** need to prepare for that.

## envars.sh

You only need concern yourself with two files:

 - `prepareMasterAndSlave.sh`
 - `envars.sh`

The script, `prepareMasterAndSlave.sh`, does all the work according to the environment variable settings you make in `envars.sh`.

To get started you will need to copy `envars.example.sh` to `envars.sh` and adjust the values to conform to your configuration.

It is strongly recommended to set up a host alias for both targets.

##  After execution

The script `prepareMasterAndSlave.sh` does most its work in `/dev/shm` a standard shared memory ramdisk.  Rebooting destroys that content, but the root directory of the ERPNext user will have some leftover files, which the script does not purge yet.

Two new directories will be created in the Frappe Bench directory: `BaRe` and `BKP`.  BaRe contains the backup and restore handlers. `BKP` contains backup archives and some pointer files.

`/etc/mysql/mariadb.conf.d/50-server.cnf` will have been patched.

Uncomplicated firewall will have a new record allowing the slave into port 3306.

The slave user will be granted replication privilege in the master MariaDb.

`xmlstarlet` and `jq` will be installed to facilitate extracting info from XML and JSON files.

The slave database will have been replaced by a complete copy of the master database.

Parts of the slave file `site_config.json` will have been altered.

`${HOME}/.profile` will contain a new line: "`export SUDO_ASKPASS=/home/admin/.ssh/.supwd.sh;`" and a new file, `.supwd.sh`, will be stored in `${HOME}/.ssh`.  That file contains the sudo password for `${MASTER_HOST_USR}` or `${SLAVE_HOST_USR}` as appropriate.




## Log of a complete error-free execution.

The following is a plain text log of a single complete error free execution.

For something a bit easier to read, look for screenshots of a colorized terminal session in the `docs` directory.

```shell

you@xub22:~/projects/ERPNextFailOver$ ./prepareMasterAndSlave.sh;


----------------------------- Starting -----------------------------------


Checking presence of 'xmlstarlet' tool.
dpkg-query: no packages found matching xmlstarlet

* * * Do you accept to install 'xmlstarlet'  (  https://en.wikipedia.org/wiki/XMLStarlet ) * * *
Type 'y' to approve, or any other key to quit :  y
Ok.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages were automatically installed and are no longer required:
  libjq1 libonig5
Use 'sudo apt autoremove' to remove them.
The following NEW packages will be installed:
  xmlstarlet
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 265 kB of archives.
After this operation, 631 kB of additional disk space will be used.
Get:1 http://ca.archive.ubuntu.com/ubuntu jammy/universe amd64 xmlstarlet amd64 1.6.1-2.1 [265 kB]
Fetched 265 kB in 1s (430 kB/s)
Selecting previously unselected package xmlstarlet.
(Reading database ... 178079 files and directories currently installed.)
Preparing to unpack .../xmlstarlet_1.6.1-2.1_amd64.deb ...
Unpacking xmlstarlet (1.6.1-2.1) ...
Setting up xmlstarlet (1.6.1-2.1) ...
Processing triggers for man-db (2.10.2-1) ...
Processing triggers for doc-base (0.11.1) ...
Processing 1 added doc-base file...

 - Installed 'xmlstarlet'


Checking presence of 'jq' tool.
dpkg-query: no packages found matching jq

* * * Do you accept to install 'jq'  * * *
Type 'y' to approve, or any other key to quit :  y
Ok.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following NEW packages will be installed:
  jq
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 52.5 kB of archives.
After this operation, 102 kB of additional disk space will be used.
Get:1 http://ca.archive.ubuntu.com/ubuntu jammy/main amd64 jq amd64 1.6-2.1ubuntu3 [52.5 kB]
Fetched 52.5 kB in 0s (179 kB/s)
Selecting previously unselected package jq.
(Reading database ... 178326 files and directories currently installed.)
Preparing to unpack .../jq_1.6-2.1ubuntu3_amd64.deb ...
Unpacking jq (1.6-2.1ubuntu3) ...
Setting up jq (1.6-2.1ubuntu3) ...
Processing triggers for man-db (2.10.2-1) ...

 - Installed 'jq'


Loading dependencies ...
 - Sourced 'makeMasterTasks.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeMasterMariaDBconfPatch.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeMasterMariaDBScript.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'prepareMaster.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeSlaveTasks.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeSlaveMariaDBconfPatch.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeSlaveMariaDBScript.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeSlaveMariaDBScript.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeMariaDBRestartScript.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeAskPassEmitter.sh' from 'prepareMasterAndSlave.sh'
 - Sourced 'makeEnvarsFile.sh' from 'prepareMasterAndSlave.sh'

Was host alias use specified?
 - Found 'ssh-agent' already running.

                                         Adding Master host PKI key to agent
Enter passphrase for /home/you/.ssh/admin_loso_erpnext_host:
Identity added: /home/you/.ssh/admin_loso_erpnext_host (water.iridium.blue@gmail.com)

                                         Adding Slave host PKI key to agent
Enter passphrase for /home/you/.ssh/adm_stg_erpnext_host:
Identity added: /home/you/.ssh/adm_stg_erpnext_host (X22_VM)

Testing connectivity ...
 - testing with command : 'ssh admin@loso.erpnext.host "whoami"'
 - testing with command  : 'ssh adm@stg.erpnext.host "whoami"'

                  No initial configuration errors found
                               -- o 0 o --

Ready to prepare Master/Slave replication:
  - Master:
     - User: admin
     - Host: loso.erpnext.host has address 185.34.136.36
  - Slave:
     - User: adm
     - Host: stg.erpnext.host has address 85.239.234.6

Press any key to proceed :
|
|
V
Making generic host-specific scripts
 - For Master
    - Making MariaDB restart script :: /dev/shm/M_work/restartMariaDB.sh
    - Making password emitter script :: /dev/shm/M_work/.supwd.sh
    - Making environment variables file for backup and restore functions  (/dev/shm/M_work/BaRe/Master_envars.sh)
 - For Slave
    - Making MariaDB restart script :: /dev/shm/S_work/restartMariaDB.sh
    - Making password emitter script :: /dev/shm/S_work/.supwd.sh
    - Making environment variables file for backup and restore functions  (/dev/shm/S_work/BaRe/Slave_envars.sh)


Preparing master ...
Moving backup and restore handlers 'handleBackup.sh' to transfer directory '/dev/shm/M_work'
 - Making Master Tasks script :: /dev/shm/M_work/masterTasks.sh.
 - Making MariaDB script :: '/dev/shm/M_work/setUpSlave.sql'.
 - Making MariaDB config patch :: '/dev/shm/M_work/master_50-server.cnf.patch'.

Uploading Master tasks files 'M_work.tgz' to 'admin@loso.erpnext.host:/dev/shm'.
Extracting content from uploaded file 'M_work.tgz' on Master.
Executing script 'masterTasks.sh' on Master.
 - Testing 'SUDO_ASKPASS' capability. ( SUDO_ASKPASS = >< )
    - Configuration allows ASKPASS creation.
    - Found password in configuration file. Trying uploaded ASK_PASS emmitter.
 - 'SUDO_ASKPASS' environment variable is correct.


 - Installing dependencies.
dpkg-query: no packages found matching xmlstarlet
Scanning processes...                                                                                                                                                                                                                                                                               
Scanning linux images...                                                                                                                                                                                                                                                                            

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.

 - Installed xmlstarlet
 - Found jq already installed
 - Making ERPNext supervisor restart script :: '/home/admin/restartERPNextSupervisor.sh'
 - Checking Frappe Bench directory location :: '/home/admin/frappe-bench-LENH'
 - Moving Backup and Restore handlers from '/dev/shm/M_work/BaRe' to Frappe Bench directory
 - Stopping ERPNext on Master ...

electronic_vouchers-service-Logichem: stopped
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-schedule: stopped
frappe-bench-LENH-redis:frappe-bench-LENH-redis-cache: stopped
frappe-bench-LENH-redis:frappe-bench-LENH-redis-queue: stopped
frappe-bench-LENH-redis:frappe-bench-LENH-redis-socketio: stopped
frappe-bench-LENH-web:frappe-bench-LENH-node-socketio: stopped
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-default-worker-0: stopped
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-short-worker-0: stopped
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-long-worker-0: stopped
frappe-bench-LENH-web:frappe-bench-LENH-frappe-web: stopped

     Stopped

 - Configuring MariaDB Master for replication. (/etc/mysql/mariadb.conf.d//50-server.cnf)
   - Getting database name for site 'loso.erpnext.host' from '/home/admin/frappe-bench-LENH/sites/loso.erpnext.host/site_config.json'.
   - Providing 'binlog-do-db' with its value (_091b776d72ba8e16), in patch file '/dev/shm/M_work/master_50-server.cnf.patch'.
   - Patching '50-server.cnf' with '/dev/shm/M_work/master_50-server.cnf.patch'.

patching file 50-server.cnf

       Patched

 - Restarting MariaDB
 - Taking backup of Master database ...


Loading environment variables from '/home/admin/frappe-bench-LENH/BaRe/envars.sh  '

 - Backing up "Pre-replication baseline" for site loso.erpnext.host (in /home/admin/frappe-bench-LENH/BKP).
   - Saving database views constructors to site private files directory. (db: _091b776d72ba8e16)
   - Backup command is:
        ==>  bench --site loso.erpnext.host backup --with-files > /dev/shm/backup_report.txt;
     - Will archive database (_091b776d72ba8e16) and files to /home/admin/frappe-bench-LENH/sites/loso.erpnext.host/private/backups
     - Will write log result to /dev/shm/backup_report.txt
         started ...
         ... done

 - Re-packaging database backup.
   - Comment :: "Pre-replication baseline"
   - Source : /home/admin/frappe-bench-LENH/sites/loso.erpnext.host/private/backups
   - Dest : /home/admin/frappe-bench-LENH/BKP
   - Name : 20221218_191404-loso_erpnext_host
   - Compression command is:
        ==>  tar zcvf /home/admin/frappe-bench-LENH/BKP/20221218_191404-loso_erpnext_host.tgz ./20221218_191404-loso_erpnext_host*
         started ...
         ... done

 - The 5 most recent logged repackaging results in '/home/admin/frappe-bench-LENH/BKP/NotesForBackups.txt' are :
Friday morning. :: 20221209_091609-loso_erpnext_host.tgz
Saturday morning. :: 20221210_070824-loso_erpnext_host.tgz
Wednesday morning :: 20221214_082704-loso_erpnext_host.tgz
Thursday morning :: 20221215_063242-loso_erpnext_host.tgz
Pre-replication baseline :: 20221218_191404-loso_erpnext_host.tgz

Backup process completed! Elapsed time, 0h 0m 38s seconds
 - Backup name is : '20221218_191404-loso_erpnext_host.tgz'
 - Enabling Slave user access and reading status of Master
   - Log FILE :: mariadb-bin.000020
   - Log file POSITION :: 344
   - Restrict to DATABASE :: _091b776d72ba8e16
   - Open MySql port 3306 for remote host :: 85.239.234.6
Rule added
 - Stopping MariaDB so that the backup can be restored on the Slave.
 - Packaging results into :: '/dev/shm/M_rslt.tgz'
Purging temporary files from Master.

Completed remote job : '/dev/shm/M_work/masterTasks.sh'.


Connection to loso.erpnext.host closed.
Downloading Master status file 'M_rslt.tgz' to '/dev/shm'.

Ready to 'prepareSlave'
Preparing slave ...
 - Extracting Master status values
   - Log FILE :: mariadb-bin.000020
   - Log file POSITION :: 344
 - Moving backup and restore handlers 'handleBackup.sh' to transfer directory '/dev/shm/M_work'
 - Making Slave Tasks script :: /dev/shm/S_work/slaveTasks.sh
 - Copy backup of Master ('20221218_191404-loso_erpnext_host.tgz') to Slave work directory.
 - Making MariaDB script :: /dev/shm/S_work/setUpSlave.sql
 - Making MariaDB config patch :: '/dev/shm/S_work/50-server.cnf.patch'.
 - Packaging Slave work files ('S_work.tgz') from '/dev/shm/S_work' in '/dev/shm' ...
 - Purging existing Slave work files from 'adm@stg.erpnext.host:/dev/shm'
 - Uploading Slave work files 'S_work.tgz' to 'adm@stg.erpnext.host:/dev/shm'
 - Extracting content from uploaded file 'S_work.tgz' on Slave ...
 - Executing script 'slaveTasks.sh' on Slave
 - Testing 'SUDO_ASKPASS' capability. ( SUDO_ASKPASS = >< )
    - Configuration allows ASKPASS creation.
    - Found password in configuration file. Trying uploaded ASK_PASS emmitter.
 - 'SUDO_ASKPASS' environment variable is correct.


 - Installing dependencies.
dpkg-query: no packages found matching xmlstarlet
Reading package lists...
Building dependency tree...
Reading state information...
The following NEW packages will be installed:
  xmlstarlet
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 265 kB of archives.
After this operation, 631 kB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu jammy/universe amd64 xmlstarlet amd64 1.6.1-2.1 [265 kB]
Fetched 265 kB in 1s (284 kB/s)
Selecting previously unselected package xmlstarlet.
(Reading database ... 125258 files and directories currently installed.)
Preparing to unpack .../xmlstarlet_1.6.1-2.1_amd64.deb ...
Unpacking xmlstarlet (1.6.1-2.1) ...
Setting up xmlstarlet (1.6.1-2.1) ...
Processing triggers for man-db (2.10.2-1) ...

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.

 - Installed xmlstarlet
 - Found jq already installed
 - Checking Frappe Bench directory location :: '/home/adm/frappe-bench-SERPHT'
 - Moving Backup and Restore handlers from '/dev/shm/S_work/BaRe' to Frappe Bench directory
   - Stopping ERPNext on Slave ...
electronic_vouchers-service-Logichem: stopped
frappe-bench-SERPHT-redis:frappe-bench-SERPHT-redis-cache: stopped
frappe-bench-SERPHT-redis:frappe-bench-SERPHT-redis-socketio: stopped
frappe-bench-SERPHT-web:frappe-bench-SERPHT-node-socketio: stopped
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-schedule: stopped
frappe-bench-SERPHT-redis:frappe-bench-SERPHT-redis-queue: stopped
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-short-worker-0: stopped
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-default-worker-0: stopped
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-long-worker-0: stopped
frappe-bench-SERPHT-web:frappe-bench-SERPHT-frappe-web: stopped

      Stopped

   - Move backup files from '/dev/shm/S_work' to backup directory '/home/adm/frappe-bench-SERPHT/BKP'
     Moving ...
       - 'BACKUP.txt'
       - '20221218_191404-loso_erpnext_host.tgz'

 - Ensuring MariaDB is running
SCRIPT_DIR /home/adm/frappe-bench-SERPHT/BaRe
CURR_SCRIPT_DIR /home/adm/frappe-bench-SERPHT/BaRe
SCRIPT_NAME handleRestore.sh
THIS_SCRIPT handleRestore.sh


Loading environment variables from '/home/adm/frappe-bench-SERPHT/BaRe/envars.sh  '

 - Restoring backup ...
    - File locations used:
      - SITE_PATH = sites/stg.erpnext.host
      - PRIVATE_PATH = sites/stg.erpnext.host/sites/stg.erpnext.host/private
      - BACKUPS_PATH = sites/stg.erpnext.host/sites/stg.erpnext.host/private/backups
      - FILES_PATH = sites/stg.erpnext.host/sites/stg.erpnext.host/private/files

      - SITE_ALIAS = stg_erpnext_host
      - TMP_BACKUP_DIR = /dev/shm/BKP
      - BACKUP_DIR = /home/adm/frappe-bench-SERPHT/BKP
      - BACKUP_FILE_NAME_HOLDER = /home/adm/frappe-bench-SERPHT/BKP/BACKUP.txt

Got MariaDB password from '/home/adm/frappe-bench-SERPHT/BaRe/../sites/stg.erpnext.host/site_config.json'.
    - Ensuring work directory exists
    - Getting backup file name from name holder file: '/home/adm/frappe-bench-SERPHT/BKP/BACKUP.txt'
    - Process archive file: '20221218_191404-loso_erpnext_host.tgz' into '/dev/shm/BKP'.
    - Does site name, 'loso_erpnext_host', extracted from backup file full name, match this site 'stg_erpnext_host' ??
       The backup is from a different ERPNext site.
       Will rename all backup files ...
       - '20221218_191404-loso_erpnext_host-database.sql' becomes '20221218_191404-stg_erpnext_host-database.sql'.
       - '20221218_191404-loso_erpnext_host-files.tar' becomes '20221218_191404-stg_erpnext_host-files.tar'.
       - '20221218_191404-loso_erpnext_host-private-files.tar' becomes '20221218_191404-stg_erpnext_host-private-files.tar'.
       - '20221218_191404-loso_erpnext_host-site_config_backup.json' becomes '20221218_191404-stg_erpnext_host-site_config_backup.json'.
    - patch site name with sed.  -->  '20221218_191404-stg_erpnext_host-site_config_backup.json' from 'loso.erpnext.host' to 'stg.erpnext.host'
    - Creating new package from repackaged contents of '20221218_191404-loso_erpnext_host.tgz'.
        Resulting file is -
         - /home/adm/frappe-bench-SERPHT/BKP/20221218_191404-stg_erpnext_host.tgz
    - Writing new package file name into file name holder : '/home/adm/frappe-bench-SERPHT/BKP/BACKUP.txt'.
    - Commencing decompression. Command is: 
         tar zxvf /home/adm/frappe-bench-SERPHT/BKP/20221218_191404-loso_erpnext_host.tgz
./20221218_191404-loso_erpnext_host-database.sql.gz
./20221218_191404-loso_erpnext_host-files.tar
./20221218_191404-loso_erpnext_host-private-files.tar
./20221218_191404-loso_erpnext_host-site_config_backup.json

    - Backup to be restored: /dev/shm/BKP/20221218_191404-stg_erpnext_host*
    - Should 'site_config.json' of 'stg.erpnext.host' be overwritten?
       Restore parameters file = 'yes'
      - Creating dated safety copy of 'site_config.json' :: site_config_2022-12-19_01.16.json.
    - Should 'db_password' of site 'stg.erpnext.host' be overwritten?
       Keep current database password = 'yes'
        Writing current database password into new site configuration '/dev/shm/BKP/20221218_191404-stg_erpnext_host-site_config_backup.json'.
      - Overwriting './sites/stg.erpnext.host/site_config.json' with site_config.json from backup.

      - Restoring database _091b776d72ba8e16.  Command is:
        ==>  bench  --site stg.erpnext.host --force restore --mariadb-root-password ******** \
                    --with-public-files /dev/shm/BKP/20221218_191404-stg_erpnext_host-files.tar \
                    --with-private-files /dev/shm/BKP/20221218_191404-stg_erpnext_host-private-files.tar \
                          /dev/shm/BKP/20221218_191404-stg_erpnext_host-database.sql.gz
         started ...
*** Scheduler is disabled ***
Site stg.erpnext.host has been restored with files
         ... restored

      - Restoring database views
         started ...
         ... restored

      - Restarting ERPNext
electronic_vouchers-service-Logichem: started
frappe-bench-SERPHT-redis:frappe-bench-SERPHT-redis-cache: started
frappe-bench-SERPHT-redis:frappe-bench-SERPHT-redis-queue: started
frappe-bench-SERPHT-redis:frappe-bench-SERPHT-redis-socketio: started
frappe-bench-SERPHT-web:frappe-bench-SERPHT-frappe-web: started
frappe-bench-SERPHT-web:frappe-bench-SERPHT-node-socketio: started
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-schedule: started
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-default-worker-0: started
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-short-worker-0: started
frappe-bench-SERPHT-workers:frappe-bench-SERPHT-frappe-long-worker-0: started
            restarted


Restore completed. Elapsed time, 0h 1m 44s seconds
 - Configuring MariaDB Slave for replication
 - Patching '50-server.cnf' with '/dev/shm/S_work/master_50-server.cnf.patch'
 - Restarting MariaDB
 - Enabling Slave connection to Master
 - Purging temporary files from Slave. *** SKIPPED ***

Completed remote job : '/dev/shm/S_work/slaveTasks.sh'.


 - Finished with Slave.

 - Restarting MariaDB for user 'admin' on Master host 'loso.erpnext.host'
     Active: active (running) since Mon 2022-12-19 01:17:44 CET; 51ms ago
 - Restarting MariaDB for user 'adm' on Slave host 'stg.erpnext.host'
     Active: active (running) since Mon 2022-12-19 01:17:51 CET; 22ms ago


Sleeping for 75 seconds, before checking slave status.
Found slave status to be ...
               Master_Log_File: mariadb-bin.000021
           Read_Master_Log_Pos: 344
              Slave_IO_Running: Yes
             Slave_SQL_Running: Yes
                 Last_IO_Error:
       Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates

Restarting ERPNext on Master ...
electronic_vouchers-service-Logichem: started
frappe-bench-LENH-redis:frappe-bench-LENH-redis-cache: started
frappe-bench-LENH-redis:frappe-bench-LENH-redis-queue: started
frappe-bench-LENH-redis:frappe-bench-LENH-redis-socketio: started
frappe-bench-LENH-web:frappe-bench-LENH-frappe-web: started
frappe-bench-LENH-web:frappe-bench-LENH-node-socketio: started
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-schedule: started
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-default-worker-0: started
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-short-worker-0: started
frappe-bench-LENH-workers:frappe-bench-LENH-frappe-long-worker-0: started
------------------------------ Finished ----------------------------------
you@xub22:~/projects/ERPNextFailOver$

```

