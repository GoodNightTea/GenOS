[BITS 16]
[ORG 0x1000]

; GenOS Stage 2 Bootloader
; Transitions from 16-bit real mode to 32-bit protected mode

%if 0
my smart ass said I wont need to change boot or stage2 anymore cause we got everything
this came to bite me in the ass after wanting to switch to 13h VGA. 
I questioned why tf it keeps crashing, until I searched out and found out that switching VGA state is done in the bios...
yea here we are yipee
%endif
[BITS 16]
[ORG 0x1000]

stage2_start:
    ; Set Mode 13h while still in real mode
    mov ax, 0x0013
    int 0x10
    
    ; NOW enter protected mode
    in al, 0x92
    or al, 2
    out 0x92, al
    
    lgdt [gdt_descriptor]
    
    cli
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp 0x08:protected_mode_start

; === 32-BIT PROTECTED MODE CODE ===
[BITS 32]
protected_mode_start:
    ; Set up segment registers for 32-bit mode
    mov ax, 0x10            ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack pointer
    mov esp, 0x7000         ; Safe stack location
    
    ; Keep interrupts disabled
    cli
    
    ; Copy kernel from temporary location to final location  
    ; Source: 0x2000 (where Stage 1 loaded it)
    ; Destination: 0x100000 (1MB - standard kernel location)
    mov esi, 0x2000         ; Source address
    mov edi, 0x100000       ; Destination address  
    mov ecx, 1024           ; Copy 4096 bytes (1024 dwords) to match 4KB kernel
    rep movsd               ; Copy kernel
    
    ; Jump to kernel entry point
    jmp 0x100000

; Global Descriptor Table for protected mode
gdt_start:
    ; Null descriptor (required by x86)
    dq 0
    
    ; Code segment descriptor
    dw 0xFFFF       ; Limit bits 0-15
    dw 0x0000       ; Base bits 0-15
    db 0x00         ; Base bits 16-23
    db 0x9A         ; Access: Present, Ring 0, Code, Readable
    db 0xCF         ; Flags: 4KB granularity, 32-bit, Limit bits 16-19
    db 0x00         ; Base bits 24-31
    
    ; Data segment descriptor  
    dw 0xFFFF       ; Limit bits 0-15
    dw 0x0000       ; Base bits 0-15
    db 0x00         ; Base bits 16-23
    db 0x92         ; Access: Present, Ring 0, Data, Writable
    db 0xCF         ; Flags: 4KB granularity, 32-bit, Limit bits 16-19
    db 0x00         ; Base bits 24-31
gdt_end:

; GDT descriptor for LGDT instruction
gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; GDT size - 1
    dd gdt_start                ; GDT base address

; Pad to 512 bytes
times 512-($-$$) db 0
