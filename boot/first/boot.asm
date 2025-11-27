[BITS 16]
[ORG 0x7C00]

; Kernel sectors is passed in by build script via -DKERNEL_SECTORS=xx
; Default to 32 if not specified
%ifndef KERNEL_SECTORS
    %define KERNEL_SECTORS 32
%endif

start:
    ; Initialize system
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    
    ; Store boot drive
    mov [boot_drive], dl

    ; Load Stage 2 (sector 1 -> 0x1000)
    mov ax, 1               ; Stage 2 at sector 1
    mov bx, 0x1000          ; Load to 0x1000
    mov cx, 1               ; Read 1 sector
    call read_sectors
    jc error
    
    ; Load kernel (sector 2+ -> 0x2000)
    mov ax, 2                       ; Kernel starts at sector 2
    mov bx, 0x2000                  ; Load to 0x2000 (temporary)
    mov cx, KERNEL_SECTORS          ; Dynamic sector count from build
    call read_sectors
    jc error
    
    ; Jump to Stage 2
    jmp 0x1000

error:
    ; Display 'E' on error
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
.halt:
    hlt
    jmp .halt

; Read multiple sectors with retry
; AX = starting LBA sector, BX = buffer address, CX = number of sectors
; Returns: CF clear on success, CF set on failure
read_sectors:
    pusha
    
.read_loop:
    push cx                 ; Save sector count
    push bx                 ; Save buffer address
    push ax                 ; Save current sector
    
    ; Read one sector with retry
    mov di, 3               ; Retry count
.retry:
    push di
    call read_single_sector
    pop di
    jnc .read_ok
    
    ; Reset disk and retry
    push ax
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13
    pop ax
    dec di
    jnz .retry
    
    ; All retries failed
    add sp, 6
    popa
    stc
    ret
    
.read_ok:
    pop ax
    pop bx
    pop cx
    
    inc ax                  ; Next sector
    add bx, 512             ; Next buffer position
    dec cx
    jnz .read_loop
    
    clc
    popa
    ret

; Read single sector using CHS
; AX = LBA sector, BX = buffer address
read_single_sector:
    pusha
    push bx
    
    ; LBA to CHS for 1.44MB floppy (18 sectors/track, 2 heads)
    xor dx, dx
    mov bx, 18
    div bx                  ; AX = head*cylinders + cylinder, DX = sector-1
    inc dx
    mov cl, dl              ; CL = sector (1-18)
    
    xor dx, dx
    mov bx, 2
    div bx                  ; AX = cylinder, DX = head
    mov ch, al              ; CH = cylinder
    mov dh, dl              ; DH = head
    
    pop bx
    
    mov dl, [boot_drive]
    mov ah, 0x02
    mov al, 1
    int 0x13
    
    popa
    ret

boot_drive: db 0

; Pad to 510 bytes and add boot signature
times 510-($-$$) db 0
dw 0xAA55
