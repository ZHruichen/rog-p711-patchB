# Technical notes

## Observed input path

The P711 button engine scans eight logical slots. Slot 5 is the top DPI button and normally polls GPIO P1.11 as an active-low input.

Relevant firmware data for `P711_MOUSE_V03_00_10.bin`:

- application block: `0x1C000..0x4DFFF`
- slot 5 bit-number byte: `0x38E98`
- application checksum field: little-endian `u32` at `0x4DFFC`
- checksum algorithm: unsigned 32-bit sum of little-endian words in `[0x1C000, 0x4DFFC)`

The original image maps slot 5 to bit 11 (`P1.11`). On the affected device this line remains low, so the engine continuously reports slot 5 as pressed. The sample bitmap is rebuilt from GPIO input every cycle; the failure is not caused by a persistent software latch.

## patchB change

patchB makes one functional byte change:

| Offset | Original | patchB | Meaning |
| --- | --- | --- | --- |
| `0x38E98` | `0x0B` | `0x0C` | slot 5 reads P1.12 instead of faulty P1.11 |

The checksum is then recomputed:

| Offset | Original | patchB |
| --- | --- | --- |
| `0x4DFFC` | `F3 B3 7C CF` | `F4 B3 7C CF` |

Verified hashes:

| Image | SHA-256 |
| --- | --- |
| ASUS V03.00.10 stock | `051FD11B4383B59FA10C273A692912FA750F3157068DD45CE38EAB7135C1FD12` |
| patchB | `8BB73F1132A149F5EC6B0FA34E6CC71D4A22BC36AFCE64CF00D8222A6ABE8DB0` |

## Trade-off

The patch permanently disconnects logical slot 5 from the physical DPI input. It restores normal operation on the affected device at the cost of the top DPI button. It does not repair the electrical fault and is not intended as a general firmware update.

## Flash invocation

The official updater invocation used by the installer is:

```text
peripheral_fwu_pro.exe m 1A70 1A71 112 200 FF01 FF01 4 <patched-bin> CVER:n
```

The updater and its DLL dependencies must remain in their original `Firmware` directory. They are not redistributed by this repository.
