[BITS 16]
[ORG 0x7C00]

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
    

    mov ax, 2               ; Stage 2 at sector 2
    mov bx, 0x1000          ; Load to 0x1000
    mov cx, 1               ; Read 1 sector
    call read_sectors

    
    ; Load kernel (32 sectors for 16KB)

    mov ax, 3               ; Kernel starts at sector 3  
    mov bx, 0x2000          ; Load to 0x2000 (temporary)
    mov cx, 32               ; Read 32 sectors (16KB)
    call read_sectors

    
    ; Jump to Stage 2
    jmp 0x1000


halt:
    hlt
    jmp halt

; Read multiple sectors
; AX = starting LBA sector, BX = buffer address, CX = number of sectors
read_sectors:
    pusha
    
.read_loop:
    push cx                 ; Save sector count
    push bx                 ; Save buffer address
    push ax                 ; Save current sector
    
    ; Read one sector at current position
    call read_single_sector
    
    ; Move to next sector and buffer position
    pop ax                  ; Restore current sector
    pop bx                  ; Restore buffer address
    pop cx                  ; Restore sector count
    
    inc ax                  ; Next sector
    add bx, 512             ; Next buffer position (512 bytes per sector)
    dec cx                  ; Decrement sector count
    jnz .read_loop          ; Continue if more sectors to read
    
    clc                     ; Clear carry (success)
    popa
    ret

; Read single sector using CHS addressing
; AX = LBA sector, BX = buffer address
read_single_sector:
    pusha
    push bx                 ; Save buffer address
    
    ; Convert LBA to CHS (1.44MB floppy: 18 sectors/track, 2 heads)
    xor dx, dx
    mov bx, 18              ; Sectors per track
    div bx                  ; AX = track, DX = sector
    inc dx                  ; Sectors are 1-based (1-18)
    mov cl, dl              ; CL = sector
    
    xor dx, dx  
    mov bx, 2               ; Heads per cylinder
    div bx                  ; AX = cylinder, DX = head
    mov ch, al              ; CH = cylinder
    mov dh, dl              ; DH = head
    
    pop bx                  ; Restore buffer address
    
    ; Read sector using BIOS interrupt
    mov dl, [boot_drive]    ; Drive number
    mov ah, 0x02            ; Read function
    mov al, 1               ; Read 1 sector
    int 0x13                ; BIOS disk service
    
    popa
    ret


boot_drive          db 0

; Boot sector signature
times 510-($-$$) db 0
dw 0xAA55
