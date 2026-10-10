# Kepler

Lenovo XiaoXin Pro 16 GT 2026 IPH11 laptop.

## Hardware

- **Display:** 16" OLED, 2880×1800, 120 Hz; preferred scaling 150%
- **CPU:** Intel Core Ultra X9 388H (x86_64-v3; no AVX512)
- **GPU:** Integrated Intel Arc B390
- **RAM:** 32 GB
- **Wireless:** Intel BE200 (Wi-Fi 7 / Bluetooth 5.4)

## Disks

| NVMe SSD | Layout |
| --- | --- |
| UMIS UPJYJ1TBMNV1QWY, 1 TB | 2 GiB FAT32 `/boot`; 150 GiB XFS `/`; remaining space XFS `/nix` |
| MSI M480 Pro, 2 TB | 36 GiB swap with hibernation support; remaining space XFS `/home` |

Layout definition: [disko/configurations/kepler.nix](../../../disko/configurations/kepler.nix).
