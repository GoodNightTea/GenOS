
# GenOS
A minimalist OS (depends what you classify as an OS) built from scratch as a graduation project, it's not the best but I like it. 
It is fun building upon it, even if I cause triple faults every now and then... 

## What this is
- Custom bootloader chain handling 16-bit to 32-bit mode transitions
- Interrupt-driven architecture with keyboard and timer handlers
- Direct VGA framebuffer interaction
- Memory management via circular buffers
- Pseudo random number generation

## Why snake?

After first attempting to build a full-featured OS with filesystem support (which is insane), I pivoted to something more achievable and demonstrable that doesn't require me to sacrifice my sanity.

## Features

### Low-Level Systems
- **Two-stage bootloader**: BIOS boot sector → Stage 2 loader → Kernel
- **Protected mode operation**: Full 32-bit mode with GDT configuration
- **Interrupt handling**: Custom IDT with PIC remapping (IRQ0: Timer, IRQ1: Keyboard)
- **Hardware timer**: PIT configured for 60Hz frame timing with HLT-based CPU efficiency
- **Keyboard driver**: PS/2 scancode processing with direction state machine

### Game Implementation  
- **VGA text mode driver**: Direct writes to 0xB8000 framebuffer
- **Circular queue**: Ring buffer for snake segments (up to 100 length)
- **Collision detection**: Optimized X-then-Y early-exit checking
- **Pseudo-random generation**: XorShift32 algorithm for apple spawning
- **Frame-based timing**: Interrupt-driven game loop with directional speed compensation

## Architecture 

┌─────────────────┐
│  Boot Sector    │  512 bytes, loads Stage 2
│  (Sector 0)     │  
└────────┬────────┘
         │
┌────────▼────────┐
│  Stage 2        │  Enables A20, sets up GDT,
│  (Sector 1)     │  transitions to protected mode
└────────┬────────┘
         │
┌────────▼────────┐
│  Kernel         │  Sets up IDT, initializes PIC/PIT,
│  (Sectors 2-9)  │  runs game loop
└─────────────────┘

### Memory Layout

0x00000000  - Real mode IVT
0x00007C00  - Boot sector loads here
0x00001000  - Stage 2 loads here  
0x00100000  - Kernel (1MB mark)
0x00110000  - IDT location
0x000B8000  - VGA text buffer


## Build Instructions

### Prerequisites

sudo apt install nasm qemu-system-x86

### Use
**In Qemu:**

qemu-system-x86_64 -drive file=build/images/snake-os.img,format=raw,if=floppy

## Controls

| Key | Action |
|-----|--------|
| **W / ↑** | Move Up |
| **A / ←** | Move Left |
| **S / ↓** | Move Down |
| **D / →** | Move Right |
| **ESC** | Pause Game |

## Project Structure
.
├── boot/
│   ├── first/
│   │   └── boot.asm              # 512-byte boot sector
│   └── second/
│       └── stage2.asm            # Protected mode transition
├── kernel/
│   ├── main_kernel.asm           # Game loop and system init
│   ├── keyboard/
│   │   └── keyboard_driver.asm   # Scancode processing
│   ├── timer/
│   │   └── timer_driver.asm      # PIT configuration
│   └── vga/
│       └── min_snake_vga.asm     # Framebuffer driver
└── tools/
    └── genfs_v2_builder.py       # Disk image builder

## Issues

- **Max snake length**: 100 segments before circular buffer wraparound
- **Resolution**: 80×25 characters, could make it 13h
- **No self-collision**: Snake can pass through itself (feature, enjoy it)
- **Single-threaded**: No multitasking or process management 

## Ideas

Todos:
- [ ] VGA Mode 13h (320×200 pixel graphics)
- [ ] PC speaker sound effects
- [ ] Self-collision detection
- [ ] High score persistence (filesystem integration)
- [ ] Multiple game modes (Tetris, Pong)
- [ ] Borders and aesthetics

## Contact
**Discord**: GoodNightTea

Found a bug or have questions about the implementation? Reach out!

## License

Idk what that is, just do what u want

*Built with NASM and coffee*
