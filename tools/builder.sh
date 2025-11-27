#!/bin/bash
# GenOS Build Script - Simple and Dynamic
# No custom filesystem, just raw sector layout

set -e  # Exit on error

# Configuration
BUILD_DIR="build"
IMAGE_NAME="genos.img"
IMAGE_SIZE=1474560  # 1.44MB floppy

BOOT_SRC="boot/first/boot.asm"
STAGE2_SRC="boot/second/stage2.asm"
KERNEL_SRC="kernel/main_kernel.asm"

# Output files
BOOT_BIN="$BUILD_DIR/boot.bin"
STAGE2_BIN="$BUILD_DIR/stage2.bin"
KERNEL_BIN="$BUILD_DIR/kernel.bin"
IMAGE="$BUILD_DIR/$IMAGE_NAME"

echo "=== GenOS Build Script ==="

# Create build directory
mkdir -p "$BUILD_DIR"

# Step 1: Assemble stage2 first (boot needs to know kernel size, not stage2)
echo "[1/5] Assembling Stage 2..."
nasm -f bin "$STAGE2_SRC" -o "$STAGE2_BIN"
STAGE2_SIZE=$(stat -c %s "$STAGE2_BIN")
if [ "$STAGE2_SIZE" -gt 512 ]; then
    echo "ERROR: Stage 2 is $STAGE2_SIZE bytes (max 512)"
    exit 1
fi
echo "      Stage 2: $STAGE2_SIZE bytes"

# Step 2: Assemble kernel
echo "[2/5] Assembling Kernel..."
nasm -f bin -I kernel/ "$KERNEL_SRC" -o "$KERNEL_BIN"
KERNEL_SIZE=$(stat -c %s "$KERNEL_BIN")
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "      Kernel: $KERNEL_SIZE bytes ($KERNEL_SECTORS sectors)"

if [ "$KERNEL_SECTORS" -gt 128 ]; then
    echo "ERROR: Kernel too large ($KERNEL_SECTORS sectors, max 128)"
    exit 1
fi

# Step 3: Assemble bootloader with kernel sector count
echo "[3/5] Assembling Bootloader (kernel_sectors=$KERNEL_SECTORS)..."
nasm -f bin "$BOOT_SRC" -o "$BOOT_BIN" -DKERNEL_SECTORS=$KERNEL_SECTORS
BOOT_SIZE=$(stat -c %s "$BOOT_BIN")
if [ "$BOOT_SIZE" -ne 512 ]; then
    echo "ERROR: Bootloader is $BOOT_SIZE bytes (must be 512)"
    exit 1
fi

# Step 4: Create disk image
echo "[4/5] Creating disk image..."

# Create empty image
dd if=/dev/zero of="$IMAGE" bs=1 count=$IMAGE_SIZE status=none

# Write bootloader to sector 0
dd if="$BOOT_BIN" of="$IMAGE" bs=512 seek=0 conv=notrunc status=none

# Write stage2 to sector 1
dd if="$STAGE2_BIN" of="$IMAGE" bs=512 seek=1 conv=notrunc status=none

# Write kernel starting at sector 2
dd if="$KERNEL_BIN" of="$IMAGE" bs=512 seek=2 conv=notrunc status=none

echo "[5/5] Build complete!"
echo ""
echo "=== Image Layout ==="
echo "  Sector 0:        Bootloader (512 bytes)"
echo "  Sector 1:        Stage 2 (512 bytes)"  
echo "  Sectors 2-$((KERNEL_SECTORS + 1)):     Kernel ($KERNEL_SIZE bytes, $KERNEL_SECTORS sectors)"
echo ""
echo "  Total image:     $IMAGE_SIZE bytes (1.44MB floppy)"
echo ""
echo "=== Run with ==="
echo "  qemu-system-x86_64 -drive file=$IMAGE,format=raw,if=floppy"
echo ""
echo "  Or with debug:"
echo "  qemu-system-x86_64 -drive file=$IMAGE,format=raw,if=floppy -no-reboot -no-shutdown -d int,cpu_reset"
