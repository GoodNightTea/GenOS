#!/bin/bash
# THIS IS AI GENERATED, mostly out of convinience. I had pushed off implementing the FS due to previous issues with it
# GenOS Build Script - Simple and Dynamic
# Fat 12 filesystem (somewhat implemented)
set -e  # Exit on error

# Configuration
BUILD_DIR="build"
IMAGE_NAME="genos.img"
IMAGE_SIZE=1474560  # 1.44MB floppy
TOTAL_SECTORS=2880  # 1.44MB = 2880 sectors

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

# Step 1: Assemble stage2 first
echo "[1/6] Assembling Stage 2..."
nasm -f bin "$STAGE2_SRC" -o "$STAGE2_BIN"
STAGE2_SIZE=$(stat -c %s "$STAGE2_BIN")
if [ "$STAGE2_SIZE" -gt 512 ]; then
    echo "ERROR: Stage 2 is $STAGE2_SIZE bytes (max 512)"
    exit 1
fi
echo "      Stage 2: $STAGE2_SIZE bytes"

# Step 2: Assemble kernel WITHOUT defines (to get size)
echo "[2/6] Assembling Kernel (first pass - calculating size)..."
nasm -f bin -I kernel/ "$KERNEL_SRC" -o "$KERNEL_BIN"
KERNEL_SIZE=$(stat -c %s "$KERNEL_BIN")
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "      Kernel: $KERNEL_SIZE bytes ($KERNEL_SECTORS sectors)"

if [ "$KERNEL_SECTORS" -gt 128 ]; then
    echo "ERROR: Kernel too large ($KERNEL_SECTORS sectors, max 128)"
    exit 1
fi

# Step 3: NOW calculate data region boundaries
DATA_START_SECTOR=$((2 + KERNEL_SECTORS))
DATA_SECTORS=$((TOTAL_SECTORS - DATA_START_SECTOR))

echo "      Data region: Sector $DATA_START_SECTOR - $((TOTAL_SECTORS - 1))"
echo "      Available data sectors: $DATA_SECTORS (~$((DATA_SECTORS * 512 / 1024))KB)"

# Step 4: Reassemble kernel WITH correct defines
echo "[3/6] Assembling Kernel (second pass - with data region info)..."
nasm -f bin -I kernel/ "$KERNEL_SRC" -o "$KERNEL_BIN" \
    -DDATA_START_SECTOR=$DATA_START_SECTOR \
    -DDATA_SECTORS=$DATA_SECTORS

# Verify size didn't change
KERNEL_SIZE_CHECK=$(stat -c %s "$KERNEL_BIN")
if [ "$KERNEL_SIZE_CHECK" -ne "$KERNEL_SIZE" ]; then
    echo "WARNING: Kernel size changed after adding defines!"
    echo "         First pass: $KERNEL_SIZE bytes"
    echo "         Second pass: $KERNEL_SIZE_CHECK bytes"
    echo "         Recalculating..."
    
    # Recalculate and try again
    KERNEL_SIZE=$KERNEL_SIZE_CHECK
    KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
    DATA_START_SECTOR=$((2 + KERNEL_SECTORS))
    DATA_SECTORS=$((TOTAL_SECTORS - DATA_START_SECTOR))
    
    echo "[3.5/6] Assembling Kernel (third pass - corrected)..."
    nasm -f bin -I kernel/ "$KERNEL_SRC" -o "$KERNEL_BIN" \
        -DDATA_START_SECTOR=$DATA_START_SECTOR \
        -DDATA_SECTORS=$DATA_SECTORS
fi

# Step 5: Assemble bootloader with all calculated values
echo "[4/6] Assembling Bootloader..."
nasm -f bin "$BOOT_SRC" -o "$BOOT_BIN" \
    -DKERNEL_SECTORS=$KERNEL_SECTORS \
    -DDATA_START_SECTOR=$DATA_START_SECTOR \
    -DDATA_SECTORS=$DATA_SECTORS

BOOT_SIZE=$(stat -c %s "$BOOT_BIN")
if [ "$BOOT_SIZE" -ne 512 ]; then
    echo "ERROR: Bootloader is $BOOT_SIZE bytes (must be 512)"
    exit 1
fi

# Step 6: Create disk image
echo "[5/6] Creating disk image..."

# Create empty image
dd if=/dev/zero of="$IMAGE" bs=1 count=$IMAGE_SIZE status=none

# Write bootloader to sector 0
dd if="$BOOT_BIN" of="$IMAGE" bs=512 seek=0 conv=notrunc status=none

# Write stage2 to sector 1
dd if="$STAGE2_BIN" of="$IMAGE" bs=512 seek=1 conv=notrunc status=none

# Write kernel starting at sector 2
dd if="$KERNEL_BIN" of="$IMAGE" bs=512 seek=2 conv=notrunc status=none

echo "[6/6] Build complete!"
echo ""
echo "=== Image Layout ==="
echo "  Sector 0:          Bootloader (512 bytes)"
echo "  Sector 1:          Stage 2 (512 bytes)"  
echo "  Sectors 2-$((DATA_START_SECTOR - 1)):      Kernel ($KERNEL_SIZE bytes, $KERNEL_SECTORS sectors)"
echo "  Sectors $DATA_START_SECTOR-$((TOTAL_SECTORS - 1)): Data region ($DATA_SECTORS sectors, ~$((DATA_SECTORS * 512 / 1024))KB)"
echo ""
echo "  Total image:       $IMAGE_SIZE bytes (1.44MB floppy)"
echo ""
echo "=== Run with ==="
echo "qemu-system-x86_64 -drive file=build/genos.img,format=raw,if=floppy -audiodev pa,id=speaker -machine pcspk-audiodev=speaker"
echo ""
echo "  Or with debug:"
echo "qemu-system-x86_64 -drive file=$IMAGE,format=raw,if=floppy -no-reboot -no-shutdown -d int,cpu_reset"
