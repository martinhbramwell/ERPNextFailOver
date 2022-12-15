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



###Log of a complete error-free execution.

```shell
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
0 upgraded, 1 newly installed, 0 to remove and 3 not upgraded.
Need to get 265 kB of archives.
After this operation, 631 kB of additional disk space will be used.
Get:1 http://ca.archive.ubuntu.com/ubuntu jammy/universe amd64 xmlstarlet amd64 1.6.1-2.1 [265 kB]
Fetched 265 kB in 0s (611 kB/s)    
Selecting previously unselected package xmlstarlet.
(Reading database ... 178071 files and directories currently installed.)
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
0 upgraded, 1 newly installed, 0 to remove and 3 not upgraded.
Need to get 52.5 kB of archives.
After this operation, 102 kB of additional disk space will be used.
Get:1 http://ca.archive.ubuntu.com/ubuntu jammy/main amd64 jq amd64 1.6-2.1ubuntu3 [52.5 kB]
Fetched 52.5 kB in 0s (177 kB/s)
Selecting previously unselected package jq.
(Reading database ... 178318 files and directories currently installed.)
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
 - Directly specifying hosts to ssh-agent
Agent pid 71115

                                         Adding Master host PKI to agent
Enter passphrase for /home/you/.ssh/admin_loso_erpnext_host:
Identity added: /home/you/.ssh/admin_loso_erpnext_host (mhb.warehouseman@gmail.com)

                                         Adding Slave host PKI to agent
Enter passphrase for /home/you/.ssh/adm_stg_erpnext_host:
Identity added: /home/you/.ssh/adm_stg_erpnext_host (X22_VM)

Testing connectivity ...'
 - testing with command : 'ssh admin@loso.erpnext.host "whoami"'
 - testing with command  : 'ssh adm@stg.erpnext.host "whoami"'

                  No initial configuration errors found
                               -- o 0 o --


Ready to prepare Master/Slave replication:
  - Master:
     - User: admin
     - Host: loso.erpnext.host has address 185.xxx.xxx.36
  - Slave:
     - User: adm
     - Host: stg.erpnext.host has address 85.xxx.xxx.6

Press any key to proceed :
|
|
V
Making generic host-specific scripts
 - For Master
    - Making MariaDB restart script :: /dev/shm/M_work/restartMariaDB.sh
    - Making password emitter script :: /dev/shm/M_work/.supwd.sh
    - Making environment variables file for backup and restore functions
 - For Slave
    - Making MariaDB restart script :: /dev/shm/S_work/restartMariaDB.sh
    - Making password emitter script :: /dev/shm/S_work/.supwd.sh
    - Making environment variables file for backup and restore functions
```






