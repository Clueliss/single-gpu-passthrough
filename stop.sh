#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

if [[ -f "/home/liss/.win10debugshutdown" ]]; then
    echo "doing debug stop, nothing to do"
    exit 0
fi

# Save current gnome session
su -c "gnome-session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill all user processes and display manager
systemctl stop user-$(id -u $VIRSH_USER).slice gdm.service

# Avoid framebuffers being used while unbinding
sleep 2

# Unbind framebuffers
declare -a bound_framebuffers

for vtcon in /sys/class/vtconsole/vtcon*; do
   if [[ $(cat "$vtcon/bind") == 1 ]]; then
       echo 0 > "$vtcon/bind"
       bound_framebuffers+=("$vtcon")
   fi
done

# Avoid framebuffer still being bound while GPU is unbinding
sleep 2

# Rebind primary gpu
modprobe amdgpu
driver-rebind "$VIRSH_GPU_VIDEO" amdgpu

# Unbind secondary gpu
driver-rebind "$VIRSH_SECONDARY_GPU_VIDEO" vfio-pci
modprobe -r radeon

# Rebind gpu audio
#modprobe snd_hda_intel
#driver-rebind "$VIRSH_GPU_AUDIO" snd_hda_intel

# Unbind secondary gpu audio
#driver-rebind "$VIRSH_SECONDARY_GPU_AUDIO" vfio-pci

# Avoid GPU not being initialized while rebinding framebuffer
sleep 2

# Rebind framebuffers
for vtcon in "${bound_framebuffers[@]}"; do
    echo 1 > "$vtcon/bind"
done

# Reverse cpu core isolation
systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
systemctl set-property --runtime -- init.scope AllowedCPUs=0-11

# Avoid framebuffer not being bound while gdm is starting
sleep 2

# Start display manager
systemctl restart gdm.service
