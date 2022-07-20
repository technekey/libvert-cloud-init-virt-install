### DO NOT USE, WORK IN PROGREE AROUND IMAGE DOWNLOADING

# libvert-cloud-init-virt-install
I have a simple shell script called virth-install-with-cloud-init.sh to automate VM creation using virt-install/libvert with cloud-init.  This script use is limited for linux guest VM and for cloud images.  read more detail [HERE](https://technekey.com/create-virtual-machines-using-virt-installlibvert-with-cloud-init/)

The script is escpically helpful, when you want to spawn multiple VM with a pre-defined configuration in cloud-init form. TLDR, the script is a wrapper of what is described [HERE](https://technekey.com/create-virtual-machines-using-virt-installlibvert-with-cloud-init/).
 It takes < 1 minute to boot and configure using cloud-init if the image is already present on your machine. 

**See the pre-requsites and assumptions** [HERE](https://technekey.com/create-virtual-machines-using-virt-installlibvert-with-cloud-init/)

```


bash  virth-install-with-cloud-init.sh -n <VM-NAME> \
 -f  </PATH/TO/CLOUD-INIT-FILE> \
 -i <CLOUD-IMAGE-DOWNLOAD-URL> \
 -c <NUMBER-OF-CPU> \
 -m <MEMORY IN MB IN INTEGER> \
 -d <DISK IN GIG WITH A G SUFFIX> \
 -v <OS-VARIANT>
```

Example:

```
bash  virth-install-with-cloud-init.sh   -n VM-1 \
-f  my-config.yml \
-i https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
-c 2 \
-m 2048 \
-d 60G \
-v ubuntu22.04
```

Full Snipper of execution:

```
bash  virth-install-with-cloud-init.sh   -n VM-1 -f  my-config.yml   -i https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img  -c 2 -m 2048 -d 60G -v ubuntu22.04
=====================================================================================
                  Installation Info                                                
=====================================================================================
VM NAME:                                           VM-1
CLOUD-INIT FILE LOCATION:                          /home/technekey/virt_install_default/my-config.yml
CPU:                                               2
Memory                                             2048
Disk:                                              60G
Image Source:                                      https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
VM Disk Location:                                  /home/technekey/LIBVERT_VM_DISKS/LIBVERT_IMAGE_ubuntu22.04_NAME_VM-1_U1Ks8k
OS VARIANT:                                        ubuntu22.04
=====================================================================================

Wed Jun 29 04:22:04 PM CDT 2022: [Info]: Downloading the image from https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img, this typically takes 1-10 mins depending on speed of your connection
Wed Jun 29 04:22:50 PM CDT 2022: [Info]: Download finised for https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img, rc=0
Wed Jun 29 04:22:50 PM CDT 2022: [Info]: The name of the downloaded image file is jammy-server-cloudimg-amd64.img
Wed Jun 29 04:22:50 PM CDT 2022: [Info]: The image /home/technekey/vm_images/jammy-server-cloudimg-amd64.img is having qcow2 format, converting to qcow2
Wed Jun 29 04:22:52 PM CDT 2022: [Info]: Resizing the disk to 60G
Image resized.
Wed Jun 29 04:22:52 PM CDT 2022: [Info]: Creating a seeding iso to include the cloud-init data

Starting install...
Creating domain...                                                                                                                                                                                            |    0 B  00:00:00     
Domain creation completed.
Wed Jun 29 04:22:54 PM CDT 2022: [Info]: Waiting for Cloud init to complete.., ATTEMPT=1, MAX ATTEMPTS=10, Retrying in 60 seconds.
Wed Jun 29 04:23:26 PM CDT 2022: [Info]: Waiting for Cloud init to complete.., ATTEMPT=2, MAX ATTEMPTS=10, Retrying in 60 seconds.
Wed Jun 29 04:23:59 PM CDT 2022: [Info]: Waiting for Cloud init to complete.., ATTEMPT=3, MAX ATTEMPTS=10, Retrying in 60 seconds.
Wed Jun 29 04:24:01 PM CDT 2022: [Info]: Cloud init instructions are successfully executed on the guest VM(VM-1)
Id:             13
Name:           VM-1
UUID:           libvirt-268fb9c6-b1fdd-4ed8-9504-d65a8bff0d26
OS Type:        hvm
State:          running
CPU(s):         2
CPU time:       50.5s
Max memory:     2097152 KiB
Used memory:    2097152 KiB
Persistent:     yes
Autostart:      disable
Managed save:   no
Security model: apparmor
Security DOI:   0
Security label: libvirt-268fb9c6-b1fdd-4ed8-9504-d65a8bff0d26 (enforcing)

```

Printing the info of the VM:

```
virsh dominfo VM-1
Id:             13
Name:           VM-1
UUID:           libvirt-268fb9c6-b1fdd-4ed8-9504-d65a8bff0d26
OS Type:        hvm
State:          running
CPU(s):         2
CPU time:       51.1s
Max memory:     2097152 KiB
Used memory:    2097152 KiB
Persistent:     yes
Autostart:      disable
Managed save:   no
Security model: apparmor
Security DOI:   0
Security label: libvirt-268fb9c6-b1fdd-4ed8-9504-d65a8bff0d26 (enforcing)
```

Ip address of the Guest VM:

```
virsh domifaddr VM-1
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 vnet12     52:54:00:96:0f:ff    ipv4         192.168.122.29/24
```
