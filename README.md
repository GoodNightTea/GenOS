
# GenOS
A minimalist OS (depends what you classify as an OS) built from scratch as a graduation project, it's not the best but I like it. 
It is fun building upon it, even if I cause triple faults every now and then... 
### Tetris
<img width="642" height="390" alt="image" src="https://github.com/user-attachments/assets/3896338b-ce55-4927-9a46-ed050fb7cbfa" />

### Snake
<img width="642" height="390" alt="image" src="https://github.com/user-attachments/assets/1cd8dff8-d5d8-4233-bdec-9e0fde70757d" />

## What this is
- Custom bootloader chain handling 16-bit to 32-bit mode transitions
- Interrupt-driven architecture with keyboard and timer handlers
- Grid based collision system (inside of tetris)
- Direct VGA framebuffer interaction
- Memory management via circular buffers
- Pseudo random number generation

## Why?

// *After first attempting to build a full-featured OS with filesystem support (which is insane), I pivoted to something more achievable and demonstrable that doesn't require me to sacrifice my sanity.*
Well it seems like I am going to have to face my filesystem support scare one way or another, soon...
## Features

### Low-Level Systems
- **Two-stage bootloader**: BIOS boot sector → Stage 2 loader → Protected mode kernel
- **Protected mode operation**: Full 32-bit mode with GDT configuration
- **Interrupt handling**: Custom IDT with 256 entries, PIC remapping (IRQ0: Timer, IRQ1: Keyboard)
- **Hardware timer**: PIT configured at ~18.2Hz with HLT-based power management
- **Keyboard driver**: PS/2 scancode processing with press/release detection
- **VGA Mode 13h**: 320×200 resolution, 256-color palette with the most beautiful font ever created

### Snake Implementation (work in progress)
- **Circular queue**: Ring buffer for snake segments (up to 100 length)
- **Collision detection**: Optimized X-then-Y early-exit checking
- **Apple Management System**: Advanced multi-stage extremely complex fast insane quantum apple tracker (very complex)
- **Pseudo-random generation**: XorShift32 algorithm for apple spawning
- **Frame-based timing**: Interrupt-driven game loop with directional speed compensation
  
### Tetris Implementation (work in progress)
- **Grid system**: 10×19 playfield (columns 0-9, rows 0-18)
- **Collision detection**: 190-byte 2D array tracking occupied cells
- **Index-based movement**: Keyboard input controls grid indices, not raw pixels like in snake
- **Block placement**: Automatic grid registration when blocks land
- **Array Manipulation**: Checks for completed x-indices and there is one, it shifts the y indice down by one and clear the upper artifact
- **Race condition feature**: Can slide blocks at the bottom (idk if I should keep or remove it, classic tetris got it as well sooo idk o.0)

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
### Memory Layout

0x00000000  - Real mode IVT
0x00007000  - Stack 8kb allocated
0x00007C00  - Boot sector loads here
0x00001000  - Stage 2 loads here  
0x00100000  - Kernel 1MB mark, expanded to 8KB
0x00110000  - IDT (256 entries × 8 bytes)
0x000A0000  - VGA framebuffer


## Build Instructions

### Prerequisites 
```
sudo apt install nasm qemu-system-x86
```
### Compile
```
nasm -f bin boot/first/boot.asm -o build/boot.bin
nasm -f bin boot/second/stage2.asm -o build/stage2.bin
mkdir -p build/images
nasm -f bin -I kernel/ kernel/main_kernel.asm -o build/kernel.bin
; and then you can all format them together to make it bootable
python3 tools/genfs_v2_builder.py build/boot.bin build/images/genos.img build/stage2.bin build/kernel.bin

```
### Use
**In Qemu:**

qemu-system-x86_64 -drive file=build/images/genos.img,format=raw,if=floppy


## Controls

### Menu
| Key | Action |
|-----|--------|
| **1** | Play Snake |
| **2** | Play Tetris |
| **ESC** | Exit to Menu |

### Snake
| Key | Action |
|-----|--------|
| **W** | Move Up |
| **A** | Move Left |
| **S** | Move Down |
| **D** | Move Right |
| **SPACE** | Pause/Resume |
| **ESC** | Return to Menu |

### Tetris
| Key | Action |
|-----|--------|
| **A** | Move Left |
| **D** | Move Right |
| **S** | Clear Line |              // DEBUG
| **SPACE** | Pause/Resume |
| **ESC** | Return to Menu |

## Project Structure
```
.
├── boot/
│   ├── first/
│   │   └── boot.asm              # 512-byte boot sector
│   └── second/
│       └── stage2.asm            # Protected mode transition
├── kernel/
│   ├── main_kernel.asm           # System Init + Game Selection + (conditional) Snake Game loop 
│   ├── tetris.asm                # System Init + Tetris game loop 
│   ├── keyboard/
│   │   └── keyboard_driver.asm   # Scancode processing
│   ├── timer/
│   │   └── timer_driver.asm      # PIT configuration
│   ├── fonts/
│   │   └── font1.asm             # The most beautiful fon ever
│   └── vga/
│       └── 13h_vga.asm           # VGA driver
└── tools/
    └── genfs_v2_builder.py       # Disk image builder
```
## Issues
### Snake:
- **Max snake length**: 100 segments before circular buffer wraparound
- **No self-collision**: Snake can pass through itself (feature, enjoy it)
- **Single-threaded**: No multitasking or process management 
- **Race-Conditions**: Rotation issue and potential apple collision/spawning issue (unconfirmed)
### Tetris:
- **Lacking Implementation 1**: I still have to implement like everything inside the HUD that will get displayed
- **Lacking Implementation 2**: More than just an 8x8 block


## Contact
**Discord**: GoodNightTea

Found a bug or have questions about the implementation? Reach out!

## License

Idk what that is, just do what u want

*Built with NASM and coffee*
