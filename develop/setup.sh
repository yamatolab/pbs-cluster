#!/bin/bash -eu

source variables

# ==========
# Validation
# ==========

# If USERNAME is empty, print error message and exit
if [ -z "$USERNAME" ]
then
    echo "You MUST define \$USERNAME value in 'variables' file."
    exit 1
fi
# If dist is empty or unset, then set default value to DIST
if [ -z "$DIST" ]; then DIST=dist; fi

# =============
# Prepare build
# =============
mkdir -p $DIST

# =============
# Setup Network
# =============
echo "Start creating VM Network..."

# Create your network definition file
template_network_file=templates/network.xml
sed "s/TEMPLATE_NETWORK_NAME/${NETWORK_NAME}/g" $template_network_file > $DIST/network.xml
sed -i -e "s/TEMPLATE_BRIDGE_NAME/${BRIDGE_NAME}/g" $DIST/network.xml
sed -i -e "s/TEMPLATE_GATEWAY_ADDRESS/${GATEWAY_ADDRESS}/g" $DIST/network.xml
sed -i -e "s/TEMPLATE_NETMASK/${NETMASK}/g" $DIST/network.xml
sed -i -e "s/TEMPLATE_DHCP_START_ADDRESS/${DHCP_START_ADDRESS}/g" $DIST/network.xml
sed -i -e "s/TEMPLATE_DHCP_END_ADDRESS/${DHCP_END_ADDRESS}/g" $DIST/network.xml

# Define your network and activate
sudo virsh net-define $DIST/network.xml
sudo virsh net-start $NETWORK_NAME

echo "Network creation finished successfully!"

# ==========
# Setup VMs
# ==========
echo "Start setup VMs"

# Download ISO
echo "Start downloading ISO"
curl -L -o $DIST/$OS_ISO_FILE $OS_ISO_URL

# To allow qemu to read your home directory,
# you need to set Access Control List of SELinux.
sudo setfacl -m u:qemu:rx $HOME

## Define a function that create one VM with name given
## The first argument is name of virtual machine
function create_vm {
    local vm_name=$1

    # This command creates:
    # - RAM: 2GB
    # - CPU: 2cores
    # - HDD: 40GB
    # with kickstart file that is accessable from the VM created 
    sudo virt-install \
        --name $vm_name \
        --virt-type kvm \
        --ram 2048 \
        --vcpus 2 \
        --arch $OS_ARCH \
        --os-variant detect=on \
        --boot hd \
        --disk size=40 \
        --network network=$NETWORK_NAME \
        --graphics vnc \
        --serial pty \
        --console pty \
        --location $DIST/$OS_ISO_FILE \
        --extra-args "inst.ks=${KS_URL}" \
        --noautoconsole \
        --wait=-1
}

echo "Start creating VMs. This takes a few minutes..."

master_name="${USERNAME}-pbs-master"
worker1_name="${USERNAME}-pbs-worker1"
worker2_name="${USERNAME}-pbs-worker2"

create_vm $master_name &
sleep $SLEEP_TIME_BETWEEN_VM_CREATION
create_vm $worker1_name &
sleep $SLEEP_TIME_BETWEEN_VM_CREATION
create_vm $worker2_name &

# Wait until all VMs are created
wait

echo "Installation finished successfully!"

# Obtain IP addresses of VMs
# To write IP addresses to ssh_config file, we need to obtain IP addresses of VMs.
REGEXP_MATCH_IP_ADDRESS='(\d{1,}\.){1,}\d{1,}'

master_ip_address=`sudo virsh domifaddr $master_name | grep -oP $REGEXP_MATCH_IP_ADDRESS`
worker1_ip_address=`sudo virsh domifaddr $worker1_name | grep -oP $REGEXP_MATCH_IP_ADDRESS`
worker2_ip_address=`sudo virsh domifaddr $worker2_name | grep -oP $REGEXP_MATCH_IP_ADDRESS`

sed "s/TEMPLATE_MASTER_HOSTNAME/${master_ip_address}/g" templates/ssh_config > ssh_config
sed -i -e "s/TEMPLATE_WORKER1_HOSTNAME/${worker1_ip_address}/g" ssh_config
sed -i -e "s/TEMPLATE_WORKER2_HOSTNAME/${worker2_ip_address}/g" ssh_config
