# Laptop

{
  disko.devices = {
    disk = {
      # 1TB NVMe - Boot, OS Root, /nix
      nvme1tb = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-UMIS_UPJYJ1TBMNV1QWY_FDBS26011JU61D254F";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            root = {
              size = "150G";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
                mountOptions = [
                  "noatime"
                  "logbsize=256k"
                ];
              };
            };

            nix = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/nix";
                mountOptions = [
                  "noatime"
                  "logbsize=256k"
                ];
              };
            };
          };
        };
      };

      # 2TB NVMe - Swap, Home Storage
      nvme2tb = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-MSI_M480_PRO_2TB_511240103464000082";

        content = {
          type = "gpt";
          partitions = {
            swap = {
              # RAM size: 32G
              size = "36G";
              content = {
                type = "swap";
                randomEncryption = false;
                resumeDevice = true;
              };
            };

            home = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/home";
                mountOptions = [
                  "noatime"
                  "logbsize=256k"
                ];
              };
            };
          };
        };
      };
    };
  };
}
