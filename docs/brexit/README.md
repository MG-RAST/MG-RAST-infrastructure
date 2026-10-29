# brexit disk layout (captured 2026-10-29, before any repair, shutdown or reboot)

Host `brexit.mcs.anl.gov` (140.221.76.26) is the only Shock backend. Its ZFS pool `boristore` has been **SUSPENDED** since about 2026-10-18 04:31, when dmesg shows an mpt3sas rescan storm. This file records where each pool disk physically sits, so a disk can be found by slot and serial, and checked again after a reboot renames every `sdX`.

## How it was built

- `zpool status -P boristore`, run on brexit as `wilke`, gives the pool members by multipath WWN (`dm-uuid-mpath-3<wwn>`).
- `/root/disk_list.21.10.2025` is a `sas3ircu` dump from 2025-10-21. Its `GUID` field equals the ZFS WWN, and it gives controller, enclosure, slot and serial. **All 150 pool members appear in it, and no disk in it is outside the pool.**
- sysfs `/sys/class/enclosure/*/<slot>/device/block` and the slot labels, read live on 2026-10-29. The HGST slot labels embed the serial, and every one of them matched the 2025 list, so the slots have not changed since 2025. Note: reading the slot `status`/`fault`/`locate` files hangs on the enclosure processor while the controllers are wedged, so do not read them now.
- `sd` names are **not stable**: they change on every reboot. Identify a disk by its **serial or WWN, and its slot**.

## Hardware

- 4 x LSI SAS9300-8e (SAS3008, firmware 16.00.10.00). In sas3ircu they are ctl0..ctl3; the Linux SCSI hosts are host6/8/9/10.
- **60 x HGST HUH721010AL5200 10 TB** in one HGST ScaleApex 4U60, dual-pathed via ctl0 and ctl3. These are raidz3-0 .. raidz3-5.
- **90 x Seagate ST6000NM0034 6 TB** in three Supermicro SAS3x48 JBODs (sas3ircu enclosures 2, 3, 4 on ctl1/ctl2), dual-pathed. These are raidz3-6 .. raidz3-14.
- 15 vdevs x raidz3 x 10 disks = 150 disks. No spares, log or cache devices.
- Root disk: `md0` RAID1 on 2 internal disks (healthy, `[UU]`). It does not depend on the pool.

## Disks that are not ONLINE right now

| vdev | state | R/W/CK | serial | WWN | chassis | slot | live sd / dm slaves |
|---|---|---|---|---|---|---|---|
| raidz3-0 | UNAVAIL was mpath 5000cca26a4d2c5c | 0/0/0 | 2THBERAD | 5000cca26a4d2c5c | HGST | 52 | none |
| raidz3-2 | OFFLINE  | 172/9.25K/0 | 2THAW6JD | 5000cca26a4c2570 | HGST | 29 | none |
| raidz3-3 | FAULTED too many errors | 3/0/0 | 2THD3JXD | 5000cca26a4e6510 | HGST | 44 | sdjp |
| raidz3-4 | UNAVAIL was mpath 5000cca26a4c6954 | 0/0/0 | 2THB0RPD | 5000cca26a4c6954 | HGST | 57 | none |
| raidz3-8 | UNAVAIL was mpath 5000c5008599b1fb | 0/0/0 | Z4D4KHXH | 5000c5008599b1fb | SMC-e3 | 19 | sdah(8:0:125:0,running) sdfy(9:0:32:0,running) |
| raidz3-13 | UNAVAIL was mpath 5000c5008599a53b | 0/0/0 | Z4D4HEKJ | 5000c5008599a53b | SMC-e3 | 26 | sdao(8:0:132:0,running) sdgf(9:0:39:0,running) |

Reading the table:
- **raidz3-8 `Z4D4KHXH` and raidz3-13 `Z4D4HEKJ` (Seagate) are UNAVAIL, yet both their SCSI paths exist and are `running`, and no multipath (`dm`) map exists for them.** The disks are probably fine. What is missing is the multipath map, so ZFS cannot open them. Check `sudo multipath -ll` before replacing anything.
- The HGST disks that are UNAVAIL, OFFLINE or FAULTED (slots 52, 57, 29, 44) are in a different situation. UNAVAIL and OFFLINE have **no** dm map **and** no live sd path, so they are really gone from the bus, or the expander dropped them.
- No vdev is at its limit: raidz3 tolerates 3 missing disks per vdev, and the worst vdevs are missing 1. But write errors on almost every HGST disk (raidz3-2 to -5 carry 30-150 each) point at the HGST chassis path (expander or cables to ctl0/ctl3), not at the disks themselves.
- **The path state is worse than the ZFS states suggest.** A suspended pool stops updating member states, so "ONLINE" above is stale. Cross-checking each disk's multipath (`dm`) map against the `sd` devices that exist now (`/sys/block/dm-*/slaves` vs `/sys/block/sd*`):

  | disks | situation now |
  |---|---|
  | 29 HGST | dm map's only slave `sd` **no longer exists**, and the disk is not visible at all |
  | 3 HGST | no dm map, and not visible (slots 52, 57, 29) |
  | 16 HGST | dm map's slave is gone; the disk **re-appeared** with 1 new `sd` path that is **not** in any dm map |
  | 12 HGST | as above, with 2 new `sd` paths, also not in any dm map |
  | 88 Seagate | dm map has 2 slaves, 1 of them gone; 2 live `sd`, of which only 1 is in the map: degraded, but has I/O |
  | 2 Seagate | no dm map, both `sd` paths live (Z4D4KHXH, Z4D4HEKJ) |

  So **all 60 HGST disks (raidz3-0 .. raidz3-5) have no working multipath path**, and 32 of them are not visible on the bus at all. That is why the pool is suspended: six whole vdevs are unreachable, not one disk per vdev. The 28 HGST disks that came back are on host6 (28 sd) and host10 (12 sd). They were never re-added to multipath, probably because `systemd-udevd` and the mpt3sas event workers are stuck in D state.
- After any HBA/chassis reset or reboot, the check is: `multipath -ll` shows 2 active paths for each of the 150 WWNs in `pool-disk-map.tsv`, and `ls /dev/disk/by-id/dm-uuid-mpath-3*` lists all 150, **before** `zpool clear` or import.

## HGST ScaleApex 4U60 (60 bays, slots 00-59), HBAs ctl0+ctl3 (60 disks)

| slot | serial | WWN | vdev | ZFS state | R/W/CK | dm (now) | dm slaves (now) |
|---|---|---|---|---|---|---|---|
| 00 | 2THBWV3D | 5000cca26a4e0068 | raidz3-0 | ONLINE | 3/4/0 | dm-0 | sdig |
| 01 | 2THDDK0D | 5000cca26a4eec40 | raidz3-5 | ONLINE | 3/84/0 | dm-49 | sdke |
| 02 | 2THDYNZD | 5000cca26a4fed70 | raidz3-0 | ONLINE | 3/4/0 | dm-1 | sdih |
| 03 | 2THBWKVD | 5000cca26a4dfc68 | raidz3-3 | ONLINE | 3/51/0 | dm-50 | sdkf |
| 04 | 2THDHGYD | 5000cca26a4f184c | raidz3-0 | ONLINE | 3/12/0 | dm-51 | sdkg |
| 05 | 2THBM3XD | 5000cca26a4d7d88 | raidz3-2 | ONLINE | 3/2/0 | dm-52 | sdkh |
| 06 | 2THB73PD | 5000cca26a4cc93c | raidz3-4 | ONLINE | 3/38/0 | dm-53 | sdki |
| 07 | 2THDWPWD | 5000cca26a4fcfd8 | raidz3-4 | ONLINE | 3/139/0 | dm-54 | sdkj |
| 08 | 2THAZ92D | 5000cca26a4c53b8 | raidz3-5 | ONLINE | 3/34/0 | dm-55 | sdkk |
| 09 | 2THBGN5D | 5000cca26a4d3a54 | raidz3-1 | ONLINE | 3/14/0 | dm-56 | sdkl |
| 10 | 2TH92B3D | 5000cca26a48dec8 | raidz3-0 | ONLINE | 3/12/0 | dm-57 | sdkm |
| 11 | 2THD6HND | 5000cca26a4e9180 | raidz3-1 | ONLINE | 3/4/0 | dm-12 | sdii |
| 12 | 2TH82VND | 5000cca26a4714d4 | raidz3-1 | ONLINE | 3/4/0 | dm-23 | sdij |
| 13 | 2THBM2GD | 5000cca26a4d7cd4 | raidz3-5 | ONLINE | 3/48/0 | dm-34 | sdik |
| 14 | 2THDNMLD | 5000cca26a4f65a0 | raidz3-2 | ONLINE | 0/131/0 | dm-44 | sdil |
| 15 | 2THDGT8D | 5000cca26a4f0dcc | raidz3-5 | ONLINE | 3/26/0 | dm-45 | sdim |
| 16 | 2TGZ5V0D | 5000cca26a36e434 | raidz3-4 | ONLINE | 3/160/0 | dm-46 | sdin |
| 17 | 2THAPVED | 5000cca26a4bd4fc | raidz3-5 | ONLINE | 3/85/0 | dm-47 | sdio |
| 18 | 2THD96KD | 5000cca26a4eba24 | raidz3-1 | ONLINE | 3/4/0 | dm-48 | sdip |
| 19 | 2THAWZJD | 5000cca26a4c3110 | raidz3-4 | ONLINE | 3/144/0 | dm-2 | sdiq |
| 20 | 2TH99Y1D | 5000cca26a495094 | raidz3-4 | ONLINE | 3/140/0 | dm-3 | sdir |
| 21 | 2THB5EHD | 5000cca26a4caff4 | raidz3-5 | ONLINE | 3/89/0 | dm-4 | sdis |
| 22 | 2THB91HD | 5000cca26a4ce634 | raidz3-4 | ONLINE | 3/147/0 | dm-5 | sdit |
| 23 | 2TH42UAD | 5000cca26a3fce40 | raidz3-2 | ONLINE | 3/96/0 | dm-6 | sdiu |
| 24 | 2THB92ZD | 5000cca26a4ce6ec | raidz3-3 | ONLINE | 3/132/0 | dm-7 | sdiv |
| 25 | 2TH9WNND | 5000cca26a4a5acc | raidz3-4 | ONLINE | 3/3/0 | dm-8 | sdiw |
| 26 | 2THA1S2D | 5000cca26a4aa70c | raidz3-2 | ONLINE | 3/112/0 | dm-9 | sdix |
| 27 | 2THDW7GD | 5000cca26a4fc8dc | raidz3-0 | ONLINE | 3/4/0 | dm-10 | sdiy |
| 28 | 2THBPPMD | 5000cca26a4da424 | raidz3-1 | ONLINE | 3/4/0 | dm-11 | sdiz |
| 29 | 2THAW6JD | 5000cca26a4c2570 | raidz3-2 | **OFFLINE** | 172/9.25K/0 | - | - |
| 30 | 2THDAVHD | 5000cca26a4ed2d0 | raidz3-3 | ONLINE | 3/119/0 | dm-14 | sdjb |
| 31 | 2TH15ZZD | 5000cca26a3a8994 | raidz3-0 | ONLINE | 3/5/0 | dm-15 | sdjc |
| 32 | 2THBES1D | 5000cca26a4d2cb4 | raidz3-1 | ONLINE | 3/4/0 | dm-16 | sdjd |
| 33 | 2THD8H5D | 5000cca26a4eaf4c | raidz3-5 | ONLINE | 3/99/0 | dm-17 | sdje |
| 34 | 2THB6TXD | 5000cca26a4cc480 | raidz3-1 | ONLINE | 3/5/0 | dm-18 | sdjf |
| 35 | 2THDP5DD | 5000cca26a4f6dc4 | raidz3-0 | ONLINE | 3/4/0 | dm-19 | sdjg |
| 36 | 2THDW05D | 5000cca26a4fc554 | raidz3-2 | ONLINE | 3/91/0 | dm-20 | sdjh |
| 37 | 2THBAHPD | 5000cca26a4cfc18 | raidz3-2 | ONLINE | 3/124/0 | dm-21 | sdji |
| 38 | 2TH94S9D | 5000cca26a4902b8 | raidz3-4 | ONLINE | 3/147/0 | dm-22 | sdjj |
| 39 | 2THD521D | 5000cca26a4e7be4 | raidz3-1 | ONLINE | 3/12/0 | dm-24 | sdjk |
| 40 | 2THAVS9D | 5000cca26a4c1e8c | raidz3-1 | ONLINE | 3/4/0 | dm-25 | sdjl |
| 41 | 2THBXKMD | 5000cca26a4e0b50 | raidz3-3 | ONLINE | 3/137/0 | dm-26 | sdjm |
| 42 | 2THB4XND | 5000cca26a4ca848 | raidz3-5 | ONLINE | 3/119/0 | dm-27 | sdjn |
| 43 | 2THDB3LD | 5000cca26a4ed6bc | raidz3-5 | ONLINE | 3/40/0 | dm-28 | sdjo |
| 44 | 2THD3JXD | 5000cca26a4e6510 | raidz3-3 | **FAULTED** | 3/0/0 | dm-29 | sdjp |
| 45 | 2THD1YED | 5000cca26a4e4d18 | raidz3-3 | ONLINE | 3/59/0 | dm-30 | sdjq |
| 46 | 2THDW8GD | 5000cca26a4fc958 | raidz3-1 | ONLINE | 3/4/0 | dm-31 | sdjr |
| 47 | 2THD2ZSD | 5000cca26a4e5cc0 | raidz3-2 | ONLINE | 3/126/0 | dm-32 | sdjs |
| 48 | 2THB49ZD | 5000cca26a4c9f3c | raidz3-3 | ONLINE | 3/124/0 | dm-33 | sdjt |
| 49 | 2THBL32D | 5000cca26a4d6e1c | raidz3-4 | ONLINE | 3/99/0 | dm-35 | sdju |
| 50 | 2THATWSD | 5000cca26a4c02ac | raidz3-0 | ONLINE | 3/4/0 | dm-36 | sdjv |
| 51 | 2THBA0KD | 5000cca26a4cf4c4 | raidz3-0 | ONLINE | 3/17/0 | dm-37 | sdjw |
| 52 | 2THBERAD | 5000cca26a4d2c5c | raidz3-0 | **UNAVAIL** | 0/0/0 | - | - |
| 53 | 2TH1U2YD | 5000cca26a3ba850 | raidz3-3 | ONLINE | 3/121/0 | dm-38 | sdjy |
| 54 | 2THBES0D | 5000cca26a4d2cb0 | raidz3-3 | ONLINE | 3/117/0 | dm-39 | sdjz |
| 55 | 2THBM75D | 5000cca26a4d7f1c | raidz3-2 | ONLINE | 3/104/0 | dm-40 | sdka |
| 56 | 2THBWWND | 5000cca26a4e0128 | raidz3-3 | ONLINE | 3/129/0 | dm-41 | sdkb |
| 57 | 2THB0RPD | 5000cca26a4c6954 | raidz3-4 | **UNAVAIL** | 0/0/0 | - | - |
| 58 | 2THAAWUD | 5000cca26a4b307c | raidz3-5 | ONLINE | 3/86/0 | dm-42 | sdkd |
| 59 | 2THDZW6D | 5000cca26a4fff78 | raidz3-2 | ONLINE | 3/136/0 | dm-43 | sdkc |

## Supermicro SAS3x48 JBOD, sas3ircu encl 2 (logical ID 50030480:0927503f), HBAs ctl1+ctl2 (12 disks)

| slot | serial | WWN | vdev | ZFS state | R/W/CK | dm (now) | dm slaves (now) |
|---|---|---|---|---|---|---|---|
| 00 | Z4D4KA3Q | 5000c5008596fac3 | raidz3-11 | ONLINE | 3/18/0 | dm-58 | sdbh sdet |
| 01 | Z4D4DWRP | 5000c500859abe4f | raidz3-13 | ONLINE | 3/310/0 | dm-59 | sdbi sdeu |
| 02 | Z4D4GAE1 | 5000c50085998c27 | raidz3-10 | ONLINE | 3/115/0 | dm-138 | sdbj sdev |
| 03 | Z4D4J2WQ | 5000c500859a8dc3 | raidz3-14 | ONLINE | 3/1.09K/0 | dm-139 | sdbk sdew |
| 04 | S4D1FYJY | 5000c500b6e64347 | raidz3-12 | ONLINE | 0/0/0 | dm-140 | sdbl sdex |
| 05 | Z4D4JLVF | 5000c500859d8033 | raidz3-8 | ONLINE | 3/3/0 | dm-141 | sdbm sdey |
| 06 | Z4D4AXKG | 5000c500859d49cb | raidz3-11 | ONLINE | 3/120/0 | dm-142 | sdbn sdez |
| 07 | Z4D4DM2H | 5000c5008599a40f | raidz3-8 | ONLINE | 3/95/0 | dm-143 | sdbo sdfa |
| 08 | Z4D4JBW3 | 5000c500859b75ef | raidz3-14 | ONLINE | 3/1.36K/0 | dm-144 | sdbp sdfb |
| 09 | Z4D4HKXV | 5000c500859c706f | raidz3-9 | ONLINE | 3/6/0 | dm-145 | sdbq sdfc |
| 10 | Z4D4E61Z | 5000c500859c33f3 | raidz3-9 | ONLINE | 3/38/0 | dm-60 | sdbr sdfd |
| 11 | Z4D0ZFMY | 5000c500859b17e7 | raidz3-7 | ONLINE | 3/54/0 | dm-61 | sdbs sdfe |

## Supermicro SAS3x48 JBOD, sas3ircu encl 3 (logical ID 50030480:0927507f), HBAs ctl1+ctl2 (39 disks)

| slot | serial | WWN | vdev | ZFS state | R/W/CK | dm (now) | dm slaves (now) |
|---|---|---|---|---|---|---|---|
| 00 | Z4D3QWBV | 5000c50085a1d133 | raidz3-13 | ONLINE | 3/271/0 | dm-62 | sdbt sdff |
| 01 | Z4D4JSL4 | 5000c500859d60e3 | raidz3-8 | ONLINE | 3/118/0 | dm-63 | sdbu sdfg |
| 02 | Z4D4J7BP | 5000c500859d479b | raidz3-8 | ONLINE | 3/101/0 | dm-73 | sdbv sdfh |
| 03 | Z4D3YBC1 | 5000c50085a1d10f | raidz3-12 | ONLINE | 3/46/0 | dm-83 | sdbw sdfi |
| 04 | Z4D4KJL7 | 5000c50085994af3 | raidz3-6 | ONLINE | 3/11/0 | dm-93 | sdbx sdfj |
| 05 | Z4D4JLQ1 | 5000c500859d7fd7 | raidz3-13 | ONLINE | 3/355/0 | dm-94 | sdby sdfk |
| 06 | Z4D4EKNB | 5000c500859a9403 | raidz3-10 | ONLINE | 3/3/0 | dm-95 | sdbz sdfl |
| 07 | Z4D4KA1R | 5000c5008596fb8f | raidz3-13 | ONLINE | 3/315/0 | dm-96 | sdca sdfm |
| 08 | Z4D4KA2P | 5000c5008596fc1b | raidz3-10 | ONLINE | 3/116/0 | dm-97 | sdcb sdfn |
| 09 | Z4D3Q972 | 5000c500859d6837 | raidz3-12 | ONLINE | 3/35/0 | dm-98 | sdcc sdfo |
| 10 | Z4D12JBZ | 5000c500859b17a7 | raidz3-10 | ONLINE | 3/110/0 | dm-64 | sdcd sdfp |
| 11 | Z4D4ESPD | 5000c500859a8953 | raidz3-14 | ONLINE | 3/745/0 | dm-65 | sdce sdfq |
| 12 | Z4D40QVN | 5000c500859d47d3 | raidz3-11 | ONLINE | 3/139/0 | dm-66 | sdcf sdfr |
| 13 | Z4D4JHTM | 5000c500859a9287 | raidz3-8 | ONLINE | 3/103/0 | dm-67 | sdcg sdfs |
| 14 | Z4D4JZMR | 5000c500859d4843 | raidz3-14 | ONLINE | 3/1.02K/0 | dm-68 | sdch sdft |
| 15 | Z4D4JZMM | 5000c500859d50c3 | raidz3-12 | ONLINE | 3/43/0 | dm-69 | sdci sdfu |
| 16 | Z4D4F58A | 5000c500859d46e7 | raidz3-12 | ONLINE | 3/48/0 | dm-70 | sdcj sdfv |
| 17 | Z4D4JZM8 | 5000c500859d5093 | raidz3-8 | ONLINE | 3/15/0 | dm-71 | sdck sdfw |
| 18 | Z4D4JR0Q | 5000c500859b784b | raidz3-8 | ONLINE | 3/95/0 | dm-72 | sdcl sdfx |
| 19 | Z4D4KHXH | 5000c5008599b1fb | raidz3-8 | **UNAVAIL** | 0/0/0 | - | - |
| 20 | S4D14FX4 | 5000c50097f73783 | raidz3-9 | ONLINE | 3/28/0 | dm-74 | sdcn sdfz |
| 21 | Z4D4F8V2 | 5000c500859c4c8f | raidz3-9 | ONLINE | 3/27/0 | dm-75 | sdco sdga |
| 22 | Z4D32CXM | 5000c500859d50ef | raidz3-10 | ONLINE | 3/3/0 | dm-76 | sdcp sdgb |
| 23 | Z4D3YAXY | 5000c50085a1d113 | raidz3-6 | ONLINE | 3/339/0 | dm-77 | sdcr sdgc |
| 24 | Z4D4KHNF | 5000c5008599c253 | raidz3-11 | ONLINE | 3/139/0 | dm-78 | sdcq sdgd |
| 25 | Z4D3PDH0 | 5000c500859d67b3 | raidz3-9 | ONLINE | 0/0/0 | dm-79 | sdcs sdge |
| 26 | Z4D4HEKJ | 5000c5008599a53b | raidz3-13 | **UNAVAIL** | 0/0/0 | - | - |
| 27 | Z4D4BJCY | 5000c500859d485b | raidz3-11 | ONLINE | 3/120/0 | dm-80 | sdcu sdgg |
| 28 | Z4D2AYRS | 5000c500859c40af | raidz3-6 | ONLINE | 3/22/0 | dm-81 | sdcv sdgh |
| 29 | Z4D2E1ZC | 5000c500859c3797 | raidz3-10 | ONLINE | 3/124/0 | dm-82 | sdcw sdgi |
| 30 | Z4D4DYRC | 5000c500859c6fcb | raidz3-7 | ONLINE | 3/4/0 | dm-84 | sdcx sdgj |
| 31 | Z4D4FE8P | 5000c500859c4dc7 | raidz3-14 | ONLINE | 3/1.06K/0 | dm-85 | sdcy sdgk |
| 32 | Z4D4JZN8 | 5000c500859d506f | raidz3-7 | ONLINE | 3/4/0 | dm-86 | sdcz sdgl |
| 33 | Z4D4FHKR | 5000c500859d4773 | raidz3-6 | ONLINE | 3/294/0 | dm-87 | sdda sdgm |
| 34 | Z4D4E0E6 | 5000c500859cfa77 | raidz3-13 | ONLINE | 3/29/0 | dm-88 | sddb sdgn |
| 35 | Z4D4HSTE | 5000c500859b50b3 | raidz3-14 | ONLINE | 3/1016/0 | dm-89 | sddc sdgo |
| 36 | Z4D4JZMW | 5000c500859d47ff | raidz3-9 | ONLINE | 3/23/0 | dm-90 | sddd sdgp |
| 37 | Z4D4KA69 | 5000c5008596f757 | raidz3-9 | ONLINE | 3/32/0 | dm-91 | sdde sdgq |
| 38 | Z4D4GR88 | 5000c500859c36e7 | raidz3-12 | ONLINE | 0/0/0 | dm-92 | sddf sdgr |

## Supermicro SAS3x48 JBOD, sas3ircu encl 4 (logical ID 50030480:092750bf), HBAs ctl1+ctl2 (39 disks)

| slot | serial | WWN | vdev | ZFS state | R/W/CK | dm (now) | dm slaves (now) |
|---|---|---|---|---|---|---|---|
| 00 | Z4D4JZ26 | 5000c500859c4ee3 | raidz3-6 | ONLINE | 3/344/0 | dm-99 | sddg sdgs |
| 01 | Z4D4JZPB | 5000c500859d508f | raidz3-14 | ONLINE | 3/724/0 | dm-100 | sddh sdgt |
| 02 | Z4D4HSG5 | 5000c500859b52c7 | raidz3-7 | ONLINE | 3/1/0 | dm-111 | sddi sdgu |
| 03 | Z4D43Y4T | 5000c500859c37d3 | raidz3-12 | ONLINE | 3/165/0 | dm-122 | sddj sdgv |
| 04 | Z4D4E174 | 5000c500859cfaa3 | raidz3-10 | ONLINE | 3/83/0 | dm-132 | sddk sdgw |
| 05 | Z4D45PSV | 5000c500859abb43 | raidz3-11 | ONLINE | 3/237/0 | dm-133 | sddl sdgx |
| 06 | Z4D4J7EY | 5000c500859d4777 | raidz3-12 | ONLINE | 3/27/0 | dm-134 | sddm sdgy |
| 07 | Z4D4HHXW | 5000c500859d7c1f | raidz3-7 | ONLINE | 3/73/0 | dm-135 | sddn sdgz |
| 08 | Z4D135HE | 5000c500859b2293 | raidz3-12 | ONLINE | 3/31/0 | dm-136 | sddo sdha |
| 09 | Z4D41VSG | 5000c500859a8ce3 | raidz3-11 | ONLINE | 3/138/0 | dm-137 | sddp sdhb |
| 10 | Z4D4D9W6 | 5000c500859a9153 | raidz3-9 | ONLINE | 3/15/0 | dm-101 | sddq sdhc |
| 11 | Z4D4FVE4 | 5000c500859c33ab | raidz3-11 | ONLINE | 0/0/0 | dm-102 | sddr sdhd |
| 12 | Z4D3M4E8 | 5000c500859d69df | raidz3-8 | ONLINE | 3/66/0 | dm-103 | sdds sdhe |
| 13 | Z4D4H82W | 5000c500859c440b | raidz3-9 | ONLINE | 3/42/0 | dm-104 | sddt sdhf |
| 14 | Z4D4HSTD | 5000c500859c40c3 | raidz3-12 | ONLINE | 3/38/0 | dm-105 | sddu sdhg |
| 15 | Z4D4GVNH | 5000c5008599a7f7 | raidz3-7 | ONLINE | 3/5/0 | dm-106 | sddv sdhh |
| 16 | Z4D4AXL8 | 5000c500859d4993 | raidz3-14 | ONLINE | 3/853/0 | dm-107 | sddw sdhi |
| 17 | Z4D4K78J | 5000c50085a0e67b | raidz3-10 | ONLINE | 3/127/0 | dm-108 | sddx sdhj |
| 18 | Z4D4EE4M | 5000c500859d4f57 | raidz3-7 | ONLINE | 3/5/0 | dm-109 | sddy sdhk |
| 19 | Z4D4F523 | 5000c500859d48bb | raidz3-8 | ONLINE | 3/112/0 | dm-110 | sddz sdhl |
| 20 | Z4D4FXQA | 5000c500859d4f83 | raidz3-11 | ONLINE | 3/134/0 | dm-112 | sdea sdhm |
| 21 | Z4D4KA26 | 5000c5008596fb1f | raidz3-7 | ONLINE | 3/61/0 | dm-113 | sdeb sdhn |
| 22 | Z4D4HSLY | 5000c500859b5113 | raidz3-13 | ONLINE | 3/328/0 | dm-114 | sdec sdho |
| 23 | Z4D4JZKJ | 5000c500859d4697 | raidz3-10 | ONLINE | 3/113/0 | dm-115 | sded sdhp |
| 24 | Z4D4KHVM | 5000c5008599b50f | raidz3-7 | ONLINE | 3/148/0 | dm-116 | sdee sdhq |
| 25 | Z4D3Q97W | 5000c500859d697b | raidz3-6 | ONLINE | 3/264/0 | dm-117 | sdef sdhr |
| 26 | Z4D3NEAF | 5000c500859afb5f | raidz3-6 | ONLINE | 3/38/0 | dm-118 | sdeg sdhs |
| 27 | Z4D4K6CK | 5000c5008597f5a7 | raidz3-11 | ONLINE | 3/132/0 | dm-119 | sdeh sdht |
| 28 | Z4D4FXQF | 5000c500859d4723 | raidz3-7 | ONLINE | 3/151/0 | dm-120 | sdei sdhu |
| 29 | Z4D4H040 | 5000c500859d467f | raidz3-6 | ONLINE | 3/309/0 | dm-121 | sdej sdhv |
| 30 | Z4D4E32E | 5000c500859a8b77 | raidz3-9 | ONLINE | 3/13/0 | dm-123 | sdek sdhw |
| 31 | Z4D4FVW7 | 5000c500859c4cd3 | raidz3-10 | ONLINE | 3/120/0 | dm-124 | sdel sdhx |
| 32 | Z4D4JLV4 | 5000c500859d80cf | raidz3-6 | ONLINE | 3/58/0 | dm-125 | sdem sdhy |
| 33 | Z4D4KHWF | 5000c5008599b2c3 | raidz3-13 | ONLINE | 3/283/0 | dm-126 | sden sdhz |
| 34 | Z4D4GQY7 | 5000c500859d48bf | raidz3-14 | ONLINE | 3/1.09K/0 | dm-127 | sdeo sdia |
| 35 | Z4D4JY88 | 5000c500859d507b | raidz3-13 | ONLINE | 3/387/0 | dm-128 | sdep sdib |
| 36 | Z4D42D0L | 5000c500859c3707 | raidz3-6 | ONLINE | 3/266/0 | dm-129 | sdeq sdic |
| 37 | Z4D4DD1B | 5000c500859ab097 | raidz3-14 | ONLINE | 3/1.28K/0 | dm-130 | sder sdid |
| 38 | Z4D4GR8D | 5000c500859d488b | raidz3-13 | ONLINE | 3/287/0 | dm-131 | sdes sdie |

## Per vdev (to check after import)

- **raidz3-0** (HUH721010AL5200): HGST/52=2THBERAD **UNAVAIL**, HGST/00=2THBWV3D, HGST/51=2THBA0KD, HGST/35=2THDP5DD, HGST/10=2TH92B3D, HGST/04=2THDHGYD, HGST/50=2THATWSD, HGST/31=2TH15ZZD, HGST/27=2THDW7GD, HGST/02=2THDYNZD
- **raidz3-1** (HUH721010AL5200): HGST/46=2THDW8GD, HGST/32=2THBES1D, HGST/28=2THBPPMD, HGST/34=2THB6TXD, HGST/18=2THD96KD, HGST/40=2THAVS9D, HGST/12=2TH82VND, HGST/09=2THBGN5D, HGST/11=2THD6HND, HGST/39=2THD521D
- **raidz3-2** (HUH721010AL5200): HGST/36=2THDW05D, HGST/05=2THBM3XD, HGST/55=2THBM75D, HGST/23=2TH42UAD, HGST/14=2THDNMLD, HGST/47=2THD2ZSD, HGST/59=2THDZW6D, HGST/37=2THBAHPD, HGST/29=2THAW6JD **OFFLINE**, HGST/26=2THA1S2D
- **raidz3-3** (HUH721010AL5200): HGST/53=2TH1U2YD, HGST/56=2THBWWND, HGST/44=2THD3JXD **FAULTED**, HGST/30=2THDAVHD, HGST/24=2THB92ZD, HGST/48=2THB49ZD, HGST/45=2THD1YED, HGST/03=2THBWKVD, HGST/54=2THBES0D, HGST/41=2THBXKMD
- **raidz3-4** (HUH721010AL5200): HGST/06=2THB73PD, HGST/57=2THB0RPD **UNAVAIL**, HGST/49=2THBL32D, HGST/25=2TH9WNND, HGST/22=2THB91HD, HGST/19=2THAWZJD, HGST/16=2TGZ5V0D, HGST/07=2THDWPWD, HGST/38=2TH94S9D, HGST/20=2TH99Y1D
- **raidz3-5** (HUH721010AL5200): HGST/42=2THB4XND, HGST/21=2THB5EHD, HGST/08=2THAZ92D, HGST/01=2THDDK0D, HGST/58=2THAAWUD, HGST/15=2THDGT8D, HGST/13=2THBM2GD, HGST/17=2THAPVED, HGST/33=2THD8H5D, HGST/43=2THDB3LD
- **raidz3-6** (ST6000NM0034): SMC-e3/28=Z4D2AYRS, SMC-e4/32=Z4D4JLV4, SMC-e3/04=Z4D4KJL7, SMC-e4/25=Z4D3Q97W, SMC-e4/00=Z4D4JZ26, SMC-e4/29=Z4D4H040, SMC-e3/23=Z4D3YAXY, SMC-e3/33=Z4D4FHKR, SMC-e4/36=Z4D42D0L, SMC-e4/26=Z4D3NEAF
- **raidz3-7** (ST6000NM0034): SMC-e4/24=Z4D4KHVM, SMC-e2/11=Z4D0ZFMY, SMC-e4/07=Z4D4HHXW, SMC-e4/28=Z4D4FXQF, SMC-e4/21=Z4D4KA26, SMC-e4/02=Z4D4HSG5, SMC-e3/32=Z4D4JZN8, SMC-e3/30=Z4D4DYRC, SMC-e4/18=Z4D4EE4M, SMC-e4/15=Z4D4GVNH
- **raidz3-8** (ST6000NM0034): SMC-e3/02=Z4D4J7BP, SMC-e3/18=Z4D4JR0Q, SMC-e3/13=Z4D4JHTM, SMC-e2/05=Z4D4JLVF, SMC-e4/19=Z4D4F523, SMC-e3/01=Z4D4JSL4, SMC-e2/07=Z4D4DM2H, SMC-e4/12=Z4D3M4E8, SMC-e3/17=Z4D4JZM8, SMC-e3/19=Z4D4KHXH **UNAVAIL**
- **raidz3-9** (ST6000NM0034): SMC-e2/10=Z4D4E61Z, SMC-e4/30=Z4D4E32E, SMC-e4/10=Z4D4D9W6, SMC-e4/13=Z4D4H82W, SMC-e3/37=Z4D4KA69, SMC-e3/21=Z4D4F8V2, SMC-e3/25=Z4D3PDH0, SMC-e3/20=S4D14FX4, SMC-e3/36=Z4D4JZMW, SMC-e2/09=Z4D4HKXV
- **raidz3-10** (ST6000NM0034): SMC-e4/23=Z4D4JZKJ, SMC-e3/08=Z4D4KA2P, SMC-e3/22=Z4D32CXM, SMC-e3/06=Z4D4EKNB, SMC-e3/10=Z4D12JBZ, SMC-e2/02=Z4D4GAE1, SMC-e4/31=Z4D4FVW7, SMC-e4/04=Z4D4E174, SMC-e4/17=Z4D4K78J, SMC-e3/29=Z4D2E1ZC
- **raidz3-11** (ST6000NM0034): SMC-e2/00=Z4D4KA3Q, SMC-e4/05=Z4D45PSV, SMC-e4/27=Z4D4K6CK, SMC-e4/09=Z4D41VSG, SMC-e3/24=Z4D4KHNF, SMC-e3/12=Z4D40QVN, SMC-e4/20=Z4D4FXQA, SMC-e3/27=Z4D4BJCY, SMC-e2/06=Z4D4AXKG, SMC-e4/11=Z4D4FVE4
- **raidz3-12** (ST6000NM0034): SMC-e3/03=Z4D3YBC1, SMC-e3/16=Z4D4F58A, SMC-e3/15=Z4D4JZMM, SMC-e4/03=Z4D43Y4T, SMC-e4/08=Z4D135HE, SMC-e3/38=Z4D4GR88, SMC-e2/04=S4D1FYJY, SMC-e4/06=Z4D4J7EY, SMC-e4/14=Z4D4HSTD, SMC-e3/09=Z4D3Q972
- **raidz3-13** (ST6000NM0034): SMC-e2/01=Z4D4DWRP, SMC-e3/26=Z4D4HEKJ **UNAVAIL**, SMC-e4/38=Z4D4GR8D, SMC-e4/35=Z4D4JY88, SMC-e3/05=Z4D4JLQ1, SMC-e3/34=Z4D4E0E6, SMC-e3/00=Z4D3QWBV, SMC-e4/33=Z4D4KHWF, SMC-e4/22=Z4D4HSLY, SMC-e3/07=Z4D4KA1R
- **raidz3-14** (ST6000NM0034): SMC-e3/31=Z4D4FE8P, SMC-e2/08=Z4D4JBW3, SMC-e2/03=Z4D4J2WQ, SMC-e4/37=Z4D4DD1B, SMC-e4/01=Z4D4JZPB, SMC-e4/34=Z4D4GQY7, SMC-e3/11=Z4D4ESPD, SMC-e4/16=Z4D4AXL8, SMC-e3/14=Z4D4JZMR, SMC-e3/35=Z4D4HSTE

## Files

- `pool-disk-map.tsv`: one row per pool disk (vdev, WWN, serial, model, ZFS state and errors, 2025 sas3ircu location, live sysfs slot, dm, sd).
- `raw-2026-10-29/`: the raw captures: `zpool status -P/-L`, enclosure slot map, sd/dm/by-path/by-id, lsscsi, HBAs, plus `disk_list.21.10.2025` (sas3ircu) and its parsed `sas3ircu-2025.tsv`, `zpool-status.260518.txt` (pool status 2026-05-18) and `mdadm.disk`, all copied from `/root`.
