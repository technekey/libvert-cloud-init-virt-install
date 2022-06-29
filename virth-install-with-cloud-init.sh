#!/bin/bash
set -e 

###################################################################################################
#NOTE: DO NOT USE THIS SCRIPT FOR WINDOWS, THE MAIN PURPOSE OF THIS SCRIPT IS TO GLUE GLOUD-INIT 
###################################################################################################
#this location will store the downloaded images file for caching
# this will prevent repeated downloads
IMAGE_CHACHE=~/vm_images/

# This is the directory keeping out VM's disk
LIBVERT_VM_DISK=~/LIBVERT_VM_DISKS

#This is timeout value for cloud-init execution completion.
CLOUD_INIT_WAIT_COUNTER_MAX=10


# Function to print error
log_err()
{
	echo "$(date): [Error]: $@" >&2
}

#function to print info, I know info is also redirected to stderr. This is done
# to keep the function return values sane.
 
log_info()
{
	echo "$(date): [Info]: $@" >&2
}

#help function
show_help()
{
   echo " +++++++++++++++++++++++ This tool is written ONLY for Linux guest creation +++++++++++++++++++++++++++++++++++++++++++"
   echo "This tool assumes, that VM installations are done for default network.See below how to make it bridge nw"
   echo "This tool is a bash script wrapper to quickly create a new VM using virt-install/libvert/qumu/kvm in Linux environment."
   echo "The following command would create a VM named ubuntu-kube-master-1 by downloading image from the URL provided to '-i' flag."
   echo "The following resources would be allocated"
   echo "-c 2:    This would assign TWO VCPUS"
   echo "-m 4096: This would assign 4096M of Mem to the VM"
   echo "-d 80G:  This would assign 80G of disk to the VM" 
   echo "Example:"
   echo "bash create_vm.sh -n ubunt-kube-master-1 -f $PWD/my-config.yml   -i https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img -c 2 -m 4096 -d 80G -v <OS-variant>"

   echo "NOTE: This tool does not default to any value, to force users to set appropriate values for their environment. However, script would clearly point out what is missing if user miss any flag."
}

while getopts ":n:i:f:c:m:d:v:h" opt; do
  case ${opt} in
     n)
       VM_NAME="${OPTARG}"
       ;;
     f)
       CLOUD_INIT_FILE="${OPTARG}"
       ;;
     i)
       IMAGE_DOWNLOAD_PATH="${OPTARG}"
       ;;
     c)
       CPU="${OPTARG}"
       ;;
     m)
       MEMORY="${OPTARG}"
       ;;
     d)
       DISK="${OPTARG}"
       ;;
     v)
      OS_VARIANT="${OPTARG}"
       ;;
     h) show_help
      ;;
    \? )
      log_err "Invalid option: $OPTARG" 1>&2
      exit 0
      ;;
    : )
      log_err "Invalid option: $OPTARG requires an argument" 1>&2
      exit
      ;;
  esac
done
shift $((OPTIND -1))
: "${VM_NAME:?Missing -n <VM_NAME>}" 
: "${CLOUD_INIT_FILE:?Missing -f <CLOUD_INIT_FILE>}"
: "${IMAGE_DOWNLOAD_PATH:?Missing -i <image download path>}"
: "${CPU:?missing -c <NUM-OF_CPU>}"
: "${MEMORY:?missing -m <MEMORY>}"
: "${DISK:?missing -d <disk in G>}"
: "${OS_VARIANT:?missing -v <OS-VARIANT>, run  virt-install --osinfo list to choose most apropriate value from the list}"


if virsh list --all |grep -q "$VM_NAME" ;then
	log_err "There is a VM with the same name($VM_NAME) already present in the system."
        exit 1;

elif ! echo "$DISK" |grep -qP '^\d+G$'; then
	log_err "The Disk must be specified in INTEGER follwed by G. Eg. 40G"
        exit 2
elif ! echo "$MEMORY"|grep -Pq '^\d+$';then
	log_err "The memory must be specified in INTEGER FORMAT in MB. Eg: for 2048M use 2048."
        exit 3;
elif [ ! -d "${IMAGE_CHACHE}" ];then
	if ! mkdir -p "${IMAGE_CHACHE}";then
              log_err "Unable to create a directory called ${IMAGE_CHACHE} for storing downloaded images"
              exit 4;
        fi
elif [ ! -d "${LIBVERT_VM_DISK}" ];then
        log_info "[Info]: Creating ${LIBVERT_VM_DISK} for storing VM disk data.."
        if ! mkdir -p "${LIBVERT_VM_DISK}";then
              log_err "Unable to create a directory called ${LIBVERT_VM_DISK} for storing DISK of the VM"
              exit 5;
        fi


fi 

#make an educated guess about the image name hidden in the Download URL
image_name=$(echo "${IMAGE_DOWNLOAD_PATH}"|grep -oP '.*/\K.*?\.[-.a-z0-9]+')


if [ -z "$image_name" ];then
    echo "Unable to determine the image name from the download URL..."
    exit 1;
fi


# Create a home sweet home for the new VM(it's qcow2 and seed iso)
VM_DISK_STORAGE_LOCATION=$(mktemp -d ${LIBVERT_VM_DISK}/LIBVERT_IMAGE_"${OS_VARIANT}"_NAME_"${VM_NAME}"_XXXXXX)
chmod -R 755 "$VM_DISK_STORAGE_LOCATION"


#print the data that would be used for VM creation
echo "====================================================================================="
echo "                  Installation Info                                                "
echo "====================================================================================="
printf "%-50s %s\n" "VM NAME:"                  "$VM_NAME"
printf "%-50s %s\n" "CLOUD-INIT FILE LOCATION:" "$CLOUD_INIT_FILE"
printf "%-50s %s\n" "CPU:"                      "$CPU"
printf "%-50s %s\n" "Memory"                    "$MEMORY"
printf "%-50s %s\n" "Disk:"                     "$DISK"
printf "%-50s %s\n" "Image Source:"             "$IMAGE_DOWNLOAD_PATH"
printf "%-50s %s\n" "VM Disk Location:"         "$VM_DISK_STORAGE_LOCATION"
printf "%-50s %s\n" "OS VARIANT:"               "$OS_VARIANT"
echo -e "=====================================================================================\n"
download_cloud_image()
{
        image_full_path="$1"
         
        # disabling strict mode to print the error only for wget
        set +e 
        log_info "Downloading the image from $image_full_path, this typically takes 1-10 mins depending on speed of your connection"
        file_name_raw=$(wget -N --content-disposition "${image_full_path}" -P "${IMAGE_CHACHE}"   2>&1  |grep -E 'Server file no newer than local file |Saving to:' |grep -oP '.*?‘\K[^’]+')
        WGET_RC=${PIPESTATUS[0]}
        
        if [ "${WGET_RC}" -ne 0 ] ; then
		log_err "Download failed from ${image_full_path}, rc=${WGET_RC}"
		exit 1;
        else
                log_info "Download finised for ${image_full_path}, rc=${WGET_RC}"      
	fi
        set -e
        echo "${file_name_raw##*/}"	

}


# convert the image
convert()
{
  DISK_SIZE="$1"
  if ! echo "$DISK_SIZE" |grep -qP '^\d+G$';then
      log_err "The disk size must by in INT followed by G"
      return 2
  fi
  format=$(sudo qemu-img info  "${IMAGE_CHACHE}/${image_name}" |grep -oP 'file format:\s+\K.*')

  log_info "The image ${IMAGE_CHACHE}/${image_name} is having ${format} format, converting to qcow2"
  sudo qemu-img convert  -f "${format}"   -O qcow2  "${IMAGE_CHACHE}/${image_name}"   "$VM_DISK_STORAGE_LOCATION/${image_name}_${VM_NAME}".qcow2

  log_info "Resizing the disk to ${DISK_SIZE}"
  sudo qemu-img resize "$VM_DISK_STORAGE_LOCATION/${image_name}_${VM_NAME}.qcow2" "${DISK_SIZE}"
}

###########################################################
# Here we are merging the cloud config file to ISO
###########################################################
create_iso_with_cloud_init()
{
    log_info "Creating a seeding iso to include the cloud-init data"
    sudo cloud-localds   "${VM_DISK_STORAGE_LOCATION}/${VM_NAME}_CLOUD_INIT.iso"   "${CLOUD_INIT_FILE}"
     
}



##########################################Quick tip to tweak the virt-install command################
#To enable debug logs, use:
#     --debug flag

# To switch to default network use:               <----+
#     --network network=default,model=virtio           |
#                                                      | ------They are mutually exclusive,ie: Use only one flag at a time. 
#                                                      |
# To use the bridge network use:                  <----+  
#     --bridge=br0

# To prevent the auto attachment to the client console use:
#     --noautoconsole
######################################################################################################

do_install()
{


#--noautoconsole
#--network network=default,model=virtio \
#--bridge=br0 

sudo virt-install   --name "$VM_NAME" \
  --disk "${VM_DISK_STORAGE_LOCATION}/${image_name}_${VM_NAME}.qcow2",device=disk,bus=virtio \
  --disk "${VM_DISK_STORAGE_LOCATION}/${VM_NAME}_CLOUD_INIT.iso",device=cdrom \
  --os-variant="${OS_VARIANT}" \
  --virt-type kvm \
  --graphics none \
  --vcpus "${CPU}" \
  --memory "${MEMORY}" \
  --console pty,target_type=serial \
  --network network=default,model=virtio \
  --import \
  --noautoconsole                                           #<---remove this line to see the progress of installation, but it will make the script hang inside the console, use --wait=5 along with it
 


}

# This function block the script until "Reached target Cloud-init target" string is seen
# in the cloud init logs of the guest VM.

wait_for_cloud_init_run()
{
CLOUD_INIT_WAIT_COUNTER=0
while [ $CLOUD_INIT_WAIT_COUNTER -lt $CLOUD_INIT_WAIT_COUNTER_MAX ] ;do
        log_info "Waiting for Cloud init to complete.., ATTEMPT=$((CLOUD_INIT_WAIT_COUNTER +1)), MAX ATTEMPTS=${CLOUD_INIT_WAIT_COUNTER_MAX}, Retrying in 60 seconds."
	if sudo virt-cat  -d $VM_NAME /var/log/syslog  2>&1 |grep -q  'Reached target Cloud-init target' ;then
		log_info "Cloud init instructions are successfully executed on the guest VM($VM_NAME)"
                virsh dominfo "$VM_NAME"
	        return 0
	fi
	sleep 30;
	CLOUD_INIT_WAIT_COUNTER=$((CLOUD_INIT_WAIT_COUNTER + 1))
done
log_err "cloud-init instructions are not completed for $VM_NAME within $CLOUD_INIT_WAIT_COUNTER_MAX minutes"

virsh dominfo "$VM_NAME"
}
main()
{
    #call the download image function, get the name of the downloaded file
    image_name=$(download_cloud_image "${IMAGE_DOWNLOAD_PATH}")
    log_info "The name of the downloaded image file is $image_name"

      
    #check the format of the file and convert if needed to qcow2
    convert  "${DISK}"

    # create the iso with user data from the cloud-init file
    create_iso_with_cloud_init

    # run virt-install
    do_install

    #wait for cloud-init to complete, this happens after the virt-install is done.
    wait_for_cloud_init_run
}

########################################
# This is the entry point of this script.
########################################
main

