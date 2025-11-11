; ============================================================================
; Mode 13h VGA Driver (320x200, 256 colors)
; ============================================================================

; VGA constants
MODE13_BUFFER    equ 0xA0000
MODE13_WIDTH     equ 320
MODE13_HEIGHT    equ 200

; ============================================================================
; Drawing Functions (Mode 13h)
; ============================================================================

; Draw snake segment at grid position
; Input: EAX = grid_x (0-39), EBX = grid_y (0-24)
draw_snake_segment:
    pushad
    
    ; Convert grid to pixels
    shl eax, 3
    shl ebx, 3
    
    ; Offset by 1 pixel to leave grid visible
    inc eax
    inc ebx
    
    ; Draw 6x6 rectangle (leaving 1px border)
    mov ecx, 6
    mov edx, 6
    mov esi, 42
    call mode13_fill_rect
    
    popad
    ret
draw_apple:
    pushad
    
    ; BOUNDS CHECK
    cmp eax, 40
    jge .out_of_bounds
    cmp ebx, 25
    jge .out_of_bounds
    
    ; Convert grid to pixels
    shl eax, 3
    shl ebx, 3
    
    inc eax
    inc ebx
    
    mov ecx, 6
    mov edx, 6
    mov esi, 12
    call mode13_fill_rect
    
    popad
    ret

.out_of_bounds:
    ; DEBUG: Draw a white block at 0,0 if bounds error occurs
    mov eax, 0
    mov ebx, 0
    mov ecx, 8
    mov edx, 8
    mov esi, 15
    call mode13_fill_rect
    popad
    ret

erase_cell:
    pushad
    
    shl eax, 3
    shl ebx, 3
    
    inc eax
    inc ebx
    
    mov ecx, 6
    mov edx, 6
    mov esi, 0
    call mode13_fill_rect
    
    popad
    ret

; ----------------------------------------------------------------------------
; mode13_set_pixel: Draw single pixel
; Input: EAX = x, EBX = y, CL = color (0-255)
; ----------------------------------------------------------------------------
mode13_set_pixel:
    pushad
    
    ; Bounds check
    cmp eax, MODE13_WIDTH
    jae .done
    cmp ebx, MODE13_HEIGHT
    jae .done
    
    ; Calculate offset: y * 320 + x
    imul ebx, MODE13_WIDTH
    add ebx, eax
    
    ; Write pixel
    mov edi, MODE13_BUFFER
    add edi, ebx
    mov [edi], cl
    
.done:
    popad
    ret

; ----------------------------------------------------------------------------
; mode13_clear_screen: Fill screen with color
; Input: AL = color
; ----------------------------------------------------------------------------
mode13_clear_screen:
    pushad
    
    mov edi, MODE13_BUFFER
    mov ecx, MODE13_WIDTH * MODE13_HEIGHT
    rep stosb
    
    popad
    ret

; ----------------------------------------------------------------------------
; mode13_fill_rect: Draw filled rectangle
; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
; ----------------------------------------------------------------------------
mode13_fill_rect:
    pushad
    
    mov [m13_rect_x], eax
    mov [m13_rect_y], ebx
    mov [m13_rect_width], ecx
    mov [m13_rect_height], edx
    mov [m13_rect_color], esi
    
    xor edi, edi               ; Row counter
.row_loop:
    cmp edi, [m13_rect_height]
    jge .done
    
    ; Calculate row start: (y + row) * 320 + x
    mov eax, [m13_rect_y]
    add eax, edi
    imul eax, MODE13_WIDTH
    add eax, [m13_rect_x]
    
    push edi
    mov edi, MODE13_BUFFER
    add edi, eax
    
    ; Fill row
    mov ecx, [m13_rect_width]
    mov al, byte [m13_rect_color]
.col_loop:
    stosb
    loop .col_loop
    
    pop edi
    inc edi
    jmp .row_loop
    
.done:
    popad
    ret


; ============================================================================
; DATA SECTION FOR 13h VGA DRIVER
; ============================================================================

m13_rect_x:      dd 0
m13_rect_y:      dd 0
m13_rect_width:  dd 0
m13_rect_height: dd 0
m13_rect_color:  dd 0

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
