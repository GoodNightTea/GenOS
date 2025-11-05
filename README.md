# GenOS - Now a snake simulator?

This is a minimalist bootloader and kernel system built as a graduation project. This includes my experience creating bootloaders, protected mode transitions, interrupt handling, and VGA text display.
I now just used this project as a base for creating a very small snake game. I just couldnt be asked to create a fully fletched OS cause thats years of work and I gotta deliver something...

## Features

- Multi-stage bootloader (16-bit → 32-bit transition)
- 32-bit protected mode kernel
- Interrupt handling with PIC initialization  
- VGA text mode display with colors
- Modular architecture using NASM includes
- Custom file system (GenFS v2)

## Architecture

- **Stage 1**: 16-bit BIOS bootloader, handles disk I/O
- **Stage 2**: Protected mode transition and kernel loading
- **Kernel**: 32-bit kernel with VGA and interrupt subsystems
- **VGA Driver**: Parameter-based display functions

## Build Instructions

### Prerequisites
- NASM assembler
- Python 3
- QEMU (for testing)

### Compilation

## Compile bootloader
nasm -f bin boot.asm -o build/boot.bin

## Compile Stage 2  
nasm -f bin stage2.asm -o build/stage2.bin

## Compile kernel (with includes)
nasm -f bin -I kernel/ kernel/main_kernel.asm -o build/kernel.bin

## Create disk image using GenFS
python3 tools/genfs_v2_builder.py build/boot.bin build/images/genos.img build/stage2.bin build/kernel.bin

## Test with QEMU
qemu-system-x86_64 -drive file=build/images/genos.img,format=raw,if=floppy

## Contact
#### Discord: GoodNightTea
Found a bug or have suggestions? Please reach out!
