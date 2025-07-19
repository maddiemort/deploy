{ modulesPath
, ...
}:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };

    initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
    initrd.kernelModules = [ "nvme" ];

    growPartition = true;
  };

  fileSystems = {
    "/boot" = { device = "/dev/disk/by-uuid/8403-34A5"; fsType = "vfat"; };
    "/" = { device = "/dev/sda1"; fsType = "ext4"; };
  };
}
