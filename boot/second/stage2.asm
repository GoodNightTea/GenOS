
; GenOS Stage 2 Bootloader
; Transitions from 16-bit real mode to 32-bit protected mode

%if 0
my smart ass said I wont need to change boot or stage2 anymore cause we got everything
this came to bite me in the ass after wanting to switch to 13h VGA. 
I questioned why tf it keeps crashing, until I searched out and found out that switching VGA state is done in the bios...
yea here we are yipee
and again we gotta ugrade to 8kb...
okay that was fast, we are back at it and Imma just upgrade to 16kb cause damn this is annoying
yea that 16kb never actually worked anyway, the filesystem was just ass, time to switch to FAT12...
%endif
[BITS 16]
[ORG 0x1000]

stage2_start:
    ; Set Mode 13h while still in real mode
    mov ax, 0x0013
    int 0x10
    
    ; Enable A20 line (try multiple methods)
    call enable_a20
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Enter protected mode
    cli
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp 0x08:protected_mode_start

; ============================================================================
; A20 Enable - Multiple methods for reliability
; ============================================================================
enable_a20:
    ; Method 1: BIOS
    mov ax, 0x2401
    int 0x15
    jnc .done
    
    ; Method 2: Fast A20 (port 0x92)
    in al, 0x92
    or al, 2
    and al, 0xFE        ; Don't trigger reset
    out 0x92, al

.done:
    ret

; ============================================================================
; 32-bit Protected Mode
; ============================================================================
[BITS 32]
protected_mode_start:
    ; Set up segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack
    mov esp, 0x90000        ; Stack at 576KB (well above kernel)
    
    ; Copy kernel from 0x2000 to 0x100000
    ; We copy 64KB max to be safe (loader limits actual read)
    mov esi, 0x2000
    mov edi, 0x100000
    mov ecx, 16384          ; 64KB / 4 = 16384 dwords
    rep movsd
    
    ; Jump to kernel
    jmp 0x100000

; ============================================================================
; Global Descriptor Table
; ============================================================================
gdt_start:
    ; Null descriptor
    dq 0
    
    ; Code segment: base=0, limit=4GB, executable, readable
    dw 0xFFFF           ; Limit low
    dw 0x0000           ; Base low
    db 0x00             ; Base middle
    db 0x9A             ; Access: present, ring 0, code, readable
    db 0xCF             ; Flags: 4KB granularity, 32-bit
    db 0x00             ; Base high
    
    ; Data segment: base=0, limit=4GB, writable
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92             ; Access: present, ring 0, data, writable
    db 0xCF
    db 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start                ; NASM with ORG 0x1000 makes this absolute

; Pad to 512 bytes
times 512-($-$$) db 0
