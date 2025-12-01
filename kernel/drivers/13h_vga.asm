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
; Input: ESI = pointer to null-terminated string !only uppercase
;
;        EAX = x position, EBX = y position, DL = color
; ----------------------------------------------------------------------------
mode13_print_string:
    pushad
    mov [string_x], eax
    mov [string_y], ebx
    mov [string_color], dl
    mov [string_ptr], esi
    
.next_char:
    mov esi, [string_ptr]
    lodsb
    mov [string_ptr], esi
    
    test al, al
    jz .done
    
    ; Convert ASCII to font index
    cmp al, '0'
    jb .check_space
    cmp al, '9'
    jbe .is_digit
    cmp al, 'A'
    jb .check_space
    cmp al, 'Z'
    jbe .is_letter
    cmp al, 'a'                 ; Support lowercase too
    jb .check_space
    cmp al, 'z'
    ja .check_space
    sub al, 'a'
    add al, 10
    jmp .draw_it
    
.is_digit:
    sub al, '0'                 ; '0'-'9' → 0-9
    jmp .draw_it
    
.is_letter:
    sub al, 'A'                 ; 'A'-'Z' → 0-25
    add al, 10                  ; Offset by 10 (after digits)
    jmp .draw_it
    
.check_space:
    cmp al, ' '
    jne .skip_char              ; Unknown character, skip
    mov al, 36                  ; Space is at index 36
    jmp .draw_it
    
.draw_it:
    movzx edi, al
    shl edi, 3
    lea edi, [font_data + edi]
    
    xor ebp, ebp
.row_loop:
    cmp ebp, 8
    jge .char_done
    
    mov al, [edi]
    inc edi
    push eax
    
    xor ecx, ecx
.col_loop:
    cmp ecx, 8
    jge .next_row
    
    mov eax, [esp]
    mov edx, 7
    sub edx, ecx
    push ecx
    mov cl, dl
    shr eax, cl
    pop ecx
    
    test al, 1
    jz .skip_pixel
    
    push ecx
    push ebp
    mov eax, [string_x]
    add eax, ecx
    mov ebx, [string_y]
    add ebx, ebp
    mov cl, [string_color]
    call mode13_set_pixel
    pop ebp
    pop ecx
    
.skip_pixel:
    inc ecx
    jmp .col_loop
    
.next_row:
    pop eax
    inc ebp
    jmp .row_loop
    
.char_done:
    add dword [string_x], 8
    jmp .next_char

.skip_char:
    add dword [string_x], 8     ; Still advance for spacing
    jmp .next_char
    
.done:
    popad
    ret

string_ptr dd 0

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

; ----------------------------------------------------------------------------
; mode13_pong: Draw offbrand version of a ball (cant be asked to fix the baller function)
; Input: (Center) EAX = x, EBX = y, ECX = radius, ESI = color
; ----------------------------------------------------------------------------
mode13_pong:
	push eax
	push ebx
	mov ecx, 4
	mov edx, 4
	call mode13_fill_rect
	pop eax
	pop ebx
    ret


; ----------------------------------------------------------------------------
; mode13_rgb_rect: Draw filled rectangle with changing color per pixel
; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = starting color
; ----------------------------------------------------------------------------

mode13_rgb_rect:
    pushad
    
    mov [m13_rect_x], eax
    mov [m13_rect_y], ebx
    mov [m13_rect_width], ecx
    mov [m13_rect_height], edx
    
    xor edi, edi               ; Row counter
.row_loop:
    cmp edi, [m13_rect_height]
    jge .done
    add dword [m13_rect_color], 1 
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
; ----------------------------------------------------------------------------
; draw_border: Draws snake border
; ----------------------------------------------------------------------------
draw_border:
    pushad
    ; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    ; Top border
    mov eax, 21
    mov ebx, 21	
    mov ecx, 275
    mov edx, 3                ; 3 cells * 8 pixels
    mov esi, 15                ; White
    call mode13_fill_rect
    
    ; Bottom border
    mov eax, 21
    mov ebx, 176               ; 200 - 24
    mov ecx, 278
    mov edx, 3
    mov esi, 15
    call mode13_fill_rect
    
    ; Left border
    mov eax, 21
    mov ebx, 24
    mov ecx, 3                
    mov edx, 155
    mov esi, 15
    call mode13_fill_rect
    
    ; Right border
    mov eax, 296               ; 320 - 24
    mov ebx, 21
    mov ecx, 3
    mov edx, 155
    mov esi, 15
    call mode13_fill_rect
    
    popad
    ret


; ============================================================================
; PACMAN ASSETS
; ============================================================================

; ----------------------------------------------------------------------------
; pacman_pipe_v: Draws a vertical pipe 
; Input: EAX = x, EBX = y, ecx = width, ebx = height
; ----------------------------------------------------------------------------
pacman_pipe_v:
    pushad
    ; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    push ecx
    mov ecx, 2
    mov esi, 1
    call mode13_fill_rect
    pop ecx
    add eax, ecx
    mov ecx, 2
    mov esi, 1
    call mode13_fill_rect

.done:
    popad
    ret
    
; ----------------------------------------------------------------------------
; pacman_pipe_h: Draw a vertical pipe 
; Input: EAX = x, EBX = y, ecx = width, ebx = height
; ----------------------------------------------------------------------------
    
pacman_pipe_h:
    pushad
    ; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    push edx
    mov edx, 2
    mov esi, 1
    call mode13_fill_rect
    pop edx
    add ebx, edx
    mov edx, 2
    mov esi, 1
    call mode13_fill_rect

.done:
    popad
    ret

; ----------------------------------------------------------------------------
; pacman_pipe_h: Draw a vertical pipe 
; Input: EAX = x, EBX = y, ecx = rotation (0,1), (1,0) 
; ----------------------------------------------------------------------------
    
pacman_90:
    pushad
    ; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    ; cmp ecx for rotation
    ; vertical - horizontal (0,1)
    ; Input: EAX = x, EBX = y, CL = color (0-255)
    push ecx
    mov ecx, 5
    mov edx, 2
    mov esi, 1
    call mode13_fill_rect
    add eax, 5
    mov cl, 1
    call mode13_set_pixel
    add eax, 1
    add ebx, 1
    call mode13_set_pixel
    add ebx, edx
    mov edx, 2
    mov esi, 1
    call mode13_fill_rect
	pop ecx
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


color			 dd 0
string_x dd 0
string_y dd 0
string_color db 0

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
