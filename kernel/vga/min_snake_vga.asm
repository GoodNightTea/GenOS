; ============================================================================
; Minimal VGA Driver for Snake Game
; ============================================================================

; VGA Constants
VGA_BUFFER      equ 0xB8000
VGA_WIDTH       equ 80
VGA_HEIGHT      equ 25
PIC1_COMMAND    equ 0x20
PIC2_COMMAND    equ 0xA0

; ============================================================================
; ESSENTIAL FUNCTIONS ONLY
; ============================================================================

; ----------------------------------------------------------------------------
; vga_clear_screen: Clear entire screen with color
; Input: EAX = color
; ----------------------------------------------------------------------------
vga_clear_screen:
    pushad
    
    mov edi, VGA_BUFFER
    mov ecx, VGA_WIDTH * VGA_HEIGHT
    and eax, 0xFF
    shl eax, 8
    or eax, ' '
    rep stosw
    
    popad
    ret

; ----------------------------------------------------------------------------
; vga_write_char_at: Write single character at position
; Input: EAX = x, EBX = y, ECX = character, EDX = color
; ----------------------------------------------------------------------------
vga_write_char_at:
    pushad
    
    ; Bounds check
    cmp eax, VGA_WIDTH
    jae .done
    cmp ebx, VGA_HEIGHT
    jae .done
    
    ; Calculate position
    imul ebx, VGA_WIDTH * 2
    shl eax, 1
    mov edi, VGA_BUFFER
    add edi, ebx
    add edi, eax
    
    ; Write character with color
    mov eax, ecx
    and eax, 0xFF
    push ebx
    mov ebx, edx
    and ebx, 0xFF
    shl ebx, 8
    or eax, ebx
    pop ebx
    stosw
    
.done:
    popad
    ret

; ----------------------------------------------------------------------------
; vga_print_string_at: Print string at position
; Input: EAX = x, EBX = y, ECX = string pointer, EDX = color
; ----------------------------------------------------------------------------
vga_print_string_at:
    pushad
    
    push eax
    push ebx
    
    mov edi, VGA_BUFFER
    imul ebx, VGA_WIDTH * 2
    add edi, ebx
    shl eax, 1
    add edi, eax
    
    mov esi, ecx
.loop:
    lodsb
    test al, al
    jz .done
    
    cmp al, 10
    je .newline
    
    and eax, 0xFF
    push ebx
    mov ebx, edx
    and ebx, 0xFF
    shl ebx, 8
    or eax, ebx
    pop ebx
    stosw
    jmp .loop

.newline:
    pop ebx
    pop eax
    inc ebx
    push eax
    push ebx
    
    mov edi, VGA_BUFFER
    imul ebx, VGA_WIDTH * 2
    add edi, ebx
    shl eax, 1
    add edi, eax
    jmp .loop

.done:
    pop ebx
    pop eax
    popad
    ret

; ----------------------------------------------------------------------------
; vga_fill_rect: Fill rectangle 
; Input: EAX = x, EBX = y, ECX = width, EDX = height
;        ESI = character, EDI = color
; ----------------------------------------------------------------------------
vga_fill_rect:
    pushad
    
    mov [vga_fill_x], eax
    mov [vga_fill_y], ebx
    mov [vga_fill_width], ecx
    mov [vga_fill_height], edx
    mov [vga_fill_char], esi
    mov [vga_fill_color], edi
    
    mov dword [vga_fill_row], 0
.row_loop:
    mov eax, [vga_fill_row]
    cmp eax, [vga_fill_height]
    jae .done
    
    ; Calculate row position
    mov eax, [vga_fill_y]
    add eax, [vga_fill_row]
    imul eax, VGA_WIDTH * 2
    mov ebx, [vga_fill_x]
    shl ebx, 1
    add eax, ebx
    mov edi, VGA_BUFFER
    add edi, eax
    
    ; Fill row
    mov ecx, [vga_fill_width]
    mov eax, [vga_fill_char]
    and eax, 0xFF
    push ebx
    movzx ebx, byte [vga_fill_color]
    shl ebx, 8
    or eax, ebx
    pop ebx
.col_loop:
    stosw
    loop .col_loop
    
    inc dword [vga_fill_row]
    jmp .row_loop

.done:
    popad
    ret

; ============================================================================
; DATA SECTION FOR VGA DRIVER
; ============================================================================

vga_fill_x:      dd 0
vga_fill_y:      dd 0
vga_fill_width:  dd 0
vga_fill_height: dd 0
vga_fill_char:   dd 0
vga_fill_color:  dd 0
vga_fill_row:    dd 0

; ============================================================================
; PIC INITIALIZATION
; ============================================================================

init_pics:
    ; ICW1: Initialize both PICs
    mov al, 0x11                ; ICW1: Init + ICW4 needed
    out 0x20, al                ; Send to PIC1 command port
    out 0xA0, al                ; Send to PIC2 command port
    
    ; ICW2: Set interrupt vector offsets
    mov al, 0x20                ; PIC1 starts at INT 32 (0x20)
    out 0x21, al                ; PIC1 data port
    mov al, 0x28                ; PIC2 starts at INT 40 (0x28)
    out 0xA1, al                ; PIC2 data port
    
    ; ICW3: Setup cascade
    mov al, 0x04                ; PIC1: slave on IRQ2
    out 0x21, al
    mov al, 0x02                ; PIC2: cascade identity
    out 0xA1, al
    
    ; ICW4: Set mode
    mov al, 0x01                ; 8086 mode
    out 0x21, al
    out 0xA1, al
    
    ; OCW1 et interrupt masks (enable timer and keyboard)
    mov al, 0xFC                ; 11111100b - enable IRQ0 (timer) and IRQ1 (keyboard)
    out 0x21, al                ; Mask for PIC1
    mov al, 0xFF                ; Mask all on PIC2
    out 0xA1, al
    
    ret
