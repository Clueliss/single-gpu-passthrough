# The What and Why of GPU stealing

This is a variant/modification of the popular `Single GPU Passthrough` method 
adapted for people who have one powerful and one mediocre/garbage GPU (like me).
This allows you to  use Windows and Linux in parallel,
instead of being confined to Windows as soon as the VM starts. 

**Note: This isn't a comprehensive guide on how to do GPU passthrough, just everything (i think)
there is to know about my specific setup and how to replicate it. Please refer to the [Arch Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) if you are new to GPU Passthrough.**

**Note: The scripts are adapted to AMD hardware. I don't own and NVidia GPUs and as far as I know the 
scripts will definitely not work with NVidia setups and would need additional commands for that.
Please refer to related `Single GPU Passthrough` repos for more information.**


# General Setup

## Required File Editing
Edit the provided `kvm.conf`, `start.sh` and `stop.sh` to match your setup.

For `start.sh` and `stop.sh` you need to keep the following in mind.

- If you are **not** an AMD user you might need to add some NVidia specific stuff to `start.sh` and `stop.sh`, but since I don't own any NVidia GPUs I can't tell you what or where you need to add this. Please refer to other repos in the `Single GPU Passthrough` space.

- If you **don't** use `gdm/gnome` edit the lines mentioning `gdm.service` accordingly.

- **Related:** If you **don't** want to use [gnome-session-restore](https://github.com/Clueliss/gnome-session-restore) remove or comment out the lines mentioning it.

- If you **don't** use the `pipewire` audio server edit the lines mentioning `pipewire` and `pipewire-pulse` accordingly.

- If you have more than two files in `/sys/class/vtconsole` you need to add additional lines where they are mentioned.

<br>

## Creating the Directory Structure
Create this directory structure based with the provided files.
**Replace `YOUR_VM_NAME` with the actual name of your VM.**

```cs
📦/etc/libvirt
|__📁hooks
|  |__⚙️kvm.conf
|  |__📃qemu
|  |__📁qemu.d
|  |  |__📁YOUR_VM_NAME
|  |  |  |__📁prepare
|  |  |  |  |__📁begin
|  |  |  |  |  |__📃start.sh
|  |  |  |__📁release
|  |  |  |  |__📁end
|  |  |  |  |  |__📃stop.sh
```

<br>

## Troubleshooting

### Race conditions
> There are a few places in `start.sh` and `stop.sh` where artitficial delays are 
> inserted via `sleep` to avoid race conditions, if the handover isn't working correctly
> you could try increasing these values. I personally haven't extensively tested how low I can go
> on these, since it works and once in my life I convinced myself that I should not touch a running system.

### Xorg/X11 weirdness: startup issues
> If for some reason Xorg does not want to start up after the VM stole the GPU
> but always works when the GPU is given back
> you might want to try setting your primary GPU 
> (aka. the first GPU to output to a display) to your secondary GPU in the BIOS.

### Wayland weirdness: startup issues, fallback to Xorg
> This isn't specific to this project just a wayland issue in general, that I came across.
> _Sometimes_ if you use two GPUs that use **different** drivers wayland will
> refuse to start and gnome will always fall back to Xorg.
> The fix for this is either disabling the other GPU (not ideal) or forcing it to use the 
> same driver, this is obviously only possible if you have for example two GPUs
> that can use `amdgpu`. You can see an example on how to apply that fix further 
> down in the `My Setup->Kernel Parameters` section. This seems to be a known issue with
> wayland.

<br>

# My Setup

## Software
- Fedora 34 Workstation
- Gnome
- Pipewire
- Wayland
- SELinux disabled, because I couldn't be bothered to fix my issues with it

<br>

## Hardware
- Gigabyte B550 AORUS Pro
- AMD Ryzen R5 3600
- AMD Radeon Vega 64 (to be passed through)
- AMD Radeon R7 240

<br>

## Monitor Setup
- Monitor 1 plugged into Vega 64 via HDMI
- Monitor 2 plugged into R7 240 via VGA

The reasoning behind this rather weird configuration is that I want
to be able to access Linux even when the VM is booted, so only my primary Monitor
gets stolen by the VM. The advantage of this is that I don't have to trust Windows
to handle Discord and other applications, so it can focus solely on the game I am running and hopefully do less weird things.

So my setup seemlessly* transitions from being a dual monitor Linux setup to
a one monitor Linux, one monitor Windows setup.

*: It's obviously not completely seemless since gdm needs to be restarted on every GPU handover.

<br>

## Groups
My user is in the following groups

- `input` : for evdev passthrough
- `kvm`, `qemu`, `libvirt` : for general vm stuff

<br>

## Kernel parameters

- `amd_iommu=on` : for full virtualization
- `rd.driver.pre=vfio-pci` : force loading vfio-pci
- `radeon.si_support=0 amdgpu.si_support=1` : to force `amdgpu` instead of `radeon` for my R7 240 (since wayland wouldn't work otherwise)

> ### /etc/default/grub
> ```
> GRUB_CMDLINE_LINUX="rhgb quiet amd_iommu=on rd.driver.pre=vfio-pci radeon.si_support=0 amdgpu.si_support=1"
> ```

<br>

## Permanent Claims

I have my Vega GPU HDMI-Audio device permanently claimed, since i don't use it anyways.
That also ensures that all needed vfio kernel modules are permanently loaded. And it is one less device to detach, which _maybe_ makes it faster (haven't tested that).

> ### /etc/modprobe.d/vfio.conf
> ```
> options vfio-pci ids=VEGA_AUDIO_DEVICE_ID
> ```

You can get the GPU's PCI device id via `lspci -nnv`. Importantly this has to be the id in the square brackets at the end and not the one in front.
So in this case `1002:aaf8` and **not** `08:00.1`.

> ### lspci -nnv
> ```
> -- snip --
>
> 08:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Vega 10 HDMI Audio [Radeon Vega 56/64] [1002:aaf8]
>	Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Vega 10 HDMI Audio [Radeon Vega 56/64] [1002:aaf8]
>	Flags: fast devsel, IRQ 58, IOMMU group 17
>	Memory at fcea0000 (32-bit, non-prefetchable) [size=16K]
>	Capabilities: <access denied>
>	Kernel driver in use: vfio-pci
>	Kernel modules: snd_hda_intel
>
> -- snip --
> ```

**Don't forget to run `dracut -fv` or equivalent afterwards.**

<br>

## Session Restore

I use a tool called [gnome-session-restore](https://github.com/Clueliss/gnome-session-restore) to restore
my gnome session after getting logged out by the VM being started or stopped. Since I found it annoying that I had to
start every application by hand afterwards.

<br>

## VM Configuration

I added the XML for my VM for reference.
Most notably it has **CPU Pinning**, **[Looking Glass](https://looking-glass.io) shm**, **Keyboard/Mouse EVDev Passthrough** and **[Scream](https://github.com/duncanthrax/scream) over Ethernet** configured.
(I actually don't use [Looking Glass](https://looking-glass.io/) I just tried it out and was too lazy to remove the shm device after I found a better setup).