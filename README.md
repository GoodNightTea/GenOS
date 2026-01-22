
# GenOS
A minimal x86 operating system with games, VGA graphics, and FAT12 filesystem support for floppy disks!

## What this is
- Custom bootloader chain handling 16-bit to 32-bit mode transitions
- Interrupt-driven architecture with keyboard and timer handlers
- Grid based collision system (inside of tetris)
- Direct VGA framebuffer interaction
- Memory management via circular buffers
- Pseudo random number generation
- Integrated file system that persist data across reboot

## Features
### Low-Level Systems
- **Two-stage bootloader**: BIOS boot sector → Stage 2 loader → Protected mode kernel
- **Protected mode operation**: Full 32-bit mode with GDT configuration
- **Interrupt handling**: Custom IDT with 256 entries, PIC remapping (IRQ0: Timer, IRQ1: Keyboard)
- **Hardware timer**: PIT configured at ~18.2Hz with HLT-based power management
- **Keyboard driver**: PS/2 scancode processing with press/release detection
- **VGA Mode 13h**: 320×200 resolution, 256-color palette with the most beautiful font ever created

## Clarification on the use of AI assistance in this project:
#### AI assisted or entirely written by it:
- FDC driver (kernel/drivers/fdc/floppydisk_controller.asm)
- DMA setup (kernel/drivers/dma/direct_mem_access.asm)
- Timer system (kernel/drivers/timer/timer_driver.asm)
- IDT setup (kernel/games/global_functions.asm)
- Game of Life (kernel/games/gameoflife.asm)
- Build script (tools/builder.sh)
As well as general assistance with optimization of code and logic flow in the beginning due to lacking knowledge of x86_64 ASM

#### Human-written:
- All game flow and logic
- VGA driver and functions
- Keyboard driver and input handling
- Filesystem API and allocation bitmap
- Boot sector and Stage 2 loader
- All frontend VGA visuals
- PIT Audio driver
- The most beautiful bitmap font ever
I have tried to keep AI assistance to its minimun.

## Build Instructions

### Prerequisites 
```
sudo apt install nasm qemu-system-x86
```
### Compile
```
sh tools/dynamic_builder.sh 
```
### Use
**In Qemu:**
```
simple: qemu-system-x86_64 -drive file=build/genos.img,format=raw,if=floppy
```

```
debug:  qemu-system-x86_64 -drive file=build/genos.img,format=raw,if=floppy -no-reboot -no-shutdown -d int,cpu_reset
```

### watching the file system:
```
watch "hexdump -C build/genos.img | tail -20"
```

### flashing onto a floppy disk:
**(note)**: It is recommend to only flash onto a floppy disk adapter, as flashing onto a USB does currently not work.
```
sudo dd if=build/genos.img of=/dev/sda bs=512
```
; note the floppy disk adapter shows up as /dev/sda due to it being adapted via usb hub
```
sudo qemu-system-x86_64 -drive file=/dev/sda,format=raw,if=floppy 
```

### watching the file system live on a floppy disk (warning creates large overhead and latency):
```
sudo watch "sudo dd if=/dev/sda of=live.img"
watch "hexdump -C build/live.img | tail -20"
```
adjust latency dependent on your overhead to get a live view

this is really unecessary and needs a lot of adjusting, not recommended. 
## Controls
### Menu
| Key | Action |
|-----|--------|
| **1** | Play Snake  |
| **2** | Play Tetris |
| **3** | Game of Life  |
| **4** | Pong |
| **5** | Minimal Terminal |
| **0** | Debug |
| **ESC** | Pause |
| **spacebar** | Returns to the main MENU |
| **R** | Reset |

### Snake
| Key | Action |
|-----|--------|
| **W** | Move Up |
| **A** | Move Left |
| **S** | Move Down |
| **D** | Move Right |

### Tetris
| Key | Action |
|-----|--------|
| **A** | Move Left |
| **D** | Move Right |
| **S** | Soft Drop |             
| **SPACE** | Rotate |  
#### i need to fix the rotate keybind, rn gets fetched by return to menu

### Pong
| Key | Action |
|-----|--------|
| **A** | Player 1 left |
| **D** | Player 1 right |
| **Left-arrow** | Player 2 left |
| **Right-arrow** | Player 2 right |

### Terminal
| Key | Action |
|-----|--------|
| **MOST KEYS** | Player 1 left |
| **ENTER** | Shifts row and resets column |
| **DELETE** | Player 2 left |

### Test
| Key | Action |
|-----|--------|
| **1** | Plays a low tone |
| **0** | Plays a high tone |
### Note: each key between 1 and 0 plays a different tone, could be seen as a keyboard, but I just use it to annoy others

## STARTUP
### displays the current occupied and free sectors injected by the build script
<img width="639" height="394" alt="image" src="https://github.com/user-attachments/assets/6d021d6f-d804-487e-b0bd-16d978719cbd" />

## Main Menu
### displays the current available "games"
<img width="632" height="391" alt="image" src="https://github.com/user-attachments/assets/68bd8707-235e-4602-afcd-844f97b240da" />

### Snake
<img width="642" height="390" alt="image" src="https://github.com/user-attachments/assets/1cd8dff8-d5d8-4233-bdec-9e0fde70757d" />

### Tetris
<img width="634" height="372" alt="image" src="https://github.com/user-attachments/assets/80b80c0d-505f-4ba7-996d-4ad74efc795a" />

### Test
<img width="634" height="372" alt="image" src="https://github.com/user-attachments/assets/8f7d27d8-e329-4765-be5e-89abdfa714e2" />

### Game of Life
<img width="640" height="403" alt="image" src="https://github.com/user-attachments/assets/c7c02743-3a9a-43ad-9aeb-d708ee433bc9" />

### Pong 
<img width="640" height="403" alt="image" src="https://github.com/user-attachments/assets/ecdf5b91-db1f-4699-9506-5292f85f38fc" />

### Minimal Terminal
<img width="1443" height="439" alt="image" src="https://github.com/user-attachments/assets/22b7256a-3450-4b0d-b4bb-31285961f31b" />


```
## Architecture 

┌─────────────────┐
│   Boot Sector   │  512 bytes, loads Stage 2
│   (Sector 0)    │  
└────────┬────────┘
         │
┌────────▼────────┐
│     Stage 2     │  Enables A20, sets up GDT,
│   (Sector 1)    │  transitions to protected mode
└────────┬────────┘
         │
┌────────▼────────┐
│     Kernel      │  Sets up IDT, initializes PIC/PIT,
│   (8KB @ 1MB)   │  runs game loop
└─────────────────┘
```
```
Memory Layout
0x00000000                           Real mode IVT
0x00007000                           Stack (8KB)                    
0x00007C00                           Boot load point                      
0x00001000                           Stage 2 load point                  
0x00080000                           DMA buffer (8KB for FDC)               
0x000A0000                           VGA framebuffer (Mode 13h)         
0x00100000                           Kernel (1MB mark, dynamic size)       
0x00110000                           IDT (256 entries × 8 bytes)  
0x00200000                           Write buffer (filesystem)      
0x00200200                           Read buffer (filesystem)
```


## Project Structure
```
.
├── boot
│   ├── first
│   │   └── boot.asm
│   └── second
│       └── stage2.asm
├── build
│   ├── boot.bin
│   ├── genos.img
│   ├── kernel.bin
│   └── stage2.bin
├── kernel
│   ├── drivers
│   │   ├── audio
│   │   │   └── audio_driver.asm
│   │   ├── fonts
│   │   │   └── font1.asm
│   │   ├── keyboard
│   │   │   └── keyboard_driver.asm
│   │   ├── fdc
│   │   │   └── floppydisk_controller.asm
│   │   ├── fs
│   │   │   └── fat12.asm
│   │   ├── dma
│   │   │   └── direct_mem_access.asm
│   │   ├── keyboard
│   │   │   └── keyboard_driver.asm
│   │   ├── timer
│   │   │   └── timer_driver.asm
│   │   └── vga
│   │       └── 13h_vga.asm
│   ├── games
│   │   ├── gameoflife.asm
│   │   ├── global_functions.asm
│   │   ├── pong.asm
│   │   ├── snake.asm
│   │   ├── test.asm
│   │   └── tetris.asm
│   │   └── terminal.asm
│   └── main_kernel.asm
└── tools
    └── builder.sh

```
## Issues
- **Single-threaded**: No multitasking or process management 
### Snake:
- **Max snake length**: 100 segments before circular buffer wraparound
- **No self-collision**: Snake can pass through itself (feature, enjoy it)
- **Race-Conditions**: Rotation issue and potential apple collision/spawning issue (unconfirmed)
### Pong:
- **Ball Race**: The ball can phase into the paddle when at certain speeds or when going in from the side, still gets detected as a collision but can eat through the hud
### Tetris:
- **Keybind conflict**: the current rotate piece keybind, is conflicting with the return to menu button
### Terminal:
- **Not all ASCII chars**: current unicode characters and numbers haven't been integrated into the font and keyboard handler


## Contact
**Discord**: GoodNightTea

Found a bug or have questions about the implementation? Reach out!

## License

Idk what that is, just do what u want

*Built with NASM and coffee*
