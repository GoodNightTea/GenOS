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
; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = starting color
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
; Tetris assets
; ============================================================================
draw_block_index:
    pushad
    add eax, 1
    mov ecx, 3
    mov edx, 3
    mov esi, 2
    call mode13_fill_rect
	popad
    ret
    

    
draw_current_piece:
    ; Draws current piece at current_piece_x/y using current shape
    pushad
    
    call get_current_shape   ; ESI = bitmask
    

    ; Iterate through 4x4 bitmask
    xor ecx, ecx            ; row
    
.row_loop:
    cmp ecx, 4
    jge .done
    
    xor edx, edx            ; col
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if cell occupied
    mov edi, ecx
    shl edi, 2
    add edi, edx
    
    cmp byte [esi + edi], 0
    je .next_col
    
    ; Draw this cell
    push eax
    push ebx
    push ecx
    push edx
    
    ; Calculate pixel position
    mov eax, [current_piece_x]
    push edx
    shl edx, 2              ; col * 4 pixels
    add eax, edx
    pop edx
    
    mov ebx, [current_piece_y]
    push ecx
    shl ecx, 2              ; row * 4 pixels
    add ebx, ecx
    pop ecx
	call draw_l_index
    pop edx
    pop ecx
    pop ebx
    pop eax
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop
.done:
    popad

    ret
clear_playfield:
	pushad
    ; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    mov eax, 120
    mov ebx, 20
    mov ecx, 86
    mov edx, 158
    mov esi, 0
    call mode13_fill_rect
    popad
    ret
    
redraw_dropped:
    pushad
    xor esi, esi              
    
.row_loop:
    xor edi, edi             
    
.col_loop:
    ; Calculate grid offset: (y * 10) + x
    mov eax, esi
    imul eax, 20
    add eax, edi
    
    ; check if cell full
    cmp byte [tetris_grid + eax], 0
    je .skip_cell             ; empty like bankacc
    
    ; index full, convert
    ; x pixel = 120 + (x_index * 4)
    mov eax, edi
    imul eax, 4
    add eax, 120
    
    ; y pixel = 20 + (y_index * 4)
    mov ebx, esi
    imul ebx, 4
    add ebx, 20
    
    ; Draw the index
    push esi
    push edi
    call draw_block_index           
    pop edi
    pop esi
    
.skip_cell:
    inc edi
    cmp edi, 20               ; done with this row?
    jl .col_loop
    
    inc esi
    cmp esi, 38               ; done with all rows?
    jl .row_loop
    
    popad
    ret


extermish_line:
	pushad
	call refresh_index
	mov eax, 120
	; Calculate Y coord from CURRENT index
    mov ebx, [current_y_index] 
	imul ebx, 4
	add ebx, 20
.clear_line_y:
	mov ecx, 80
	mov edx, 4
	mov esi, 15
	call mode13_fill_rect
	popad
	ret
	


draw_hud:
    pushad

    ; Main play area border (10 blocks wide × 20 blocks tall)
    ; Using 8-pixel blocks = 80×160 pixel play area
    ; Centered-ish on screen (320×200)
    
    ; Left border (3 pixels thick)
    mov eax, 117              ; Start X (leaves room on left)
    mov ebx, 18               ; Start Y (leaves room at top)
    mov ecx, 3                ; Width
    mov esi, 15
    mov edx, 156              ; Height (20 blocks × 8 + borders)

    call mode13_fill_rect
    ; Right border
    mov eax, 201              ; 117 + 3 + 80 (play area)
    mov ebx, 18
    mov ecx, 3
    mov esi, 15
    mov edx, 156

    call mode13_fill_rect
	
    ; Top border
    mov eax, 117
    mov ebx, 17
    mov ecx, 87             ; 3 + 80 + 3 + 1 spacing
    mov edx, 3
    mov esi, 15
    call mode13_fill_rect
    ; Bottom border
    mov eax, 117
    mov ebx, 173              ; 18 + 3 + 160 (play area)
    mov ecx, 87
    mov edx, 3
    mov esi, 15
    call mode13_fill_rect
    ; Score label (top left)
    mov esi, score_text       ; "SCORE"
    mov eax, 10
    mov ebx, 30
    mov dl, 15
    call mode13_print_string
    
    
    ; Next piece label (right side)
    mov esi, next_text        ; "NEXT"
    mov eax, 220
    mov ebx, 30
    mov dl, 15
    call mode13_print_string
    
    ; Next piece preview box
    mov eax, 215
    mov ebx, 45
    mov ecx, 50
    mov edx, 50
    call mode13_fill_rect
    mov eax, 218
    mov ebx, 48
    mov ecx, 44
    mov edx, 44
    mov esi, 0
    call mode13_fill_rect
	
	mov eax, 237
	mov ebx, 60
	call draw_L
	
    popad
    ret

get_current_shape:
    ; Output: ESI = pointer to current shape bitmask
    push eax
    push ebx
    
    movzx eax, byte [current_shape_type]
    shl eax, 4              ; * 16 (4 rotations * 4 bytes per pointer)
    
    movzx ebx, byte [current_rotation]
    shl ebx, 2              ; * 4 (pointer size)
    
    add eax, ebx
    lea esi, [shape_table + eax]
    mov esi, [esi]          ; Dereference to get actual bitmask
    
    pop ebx
    pop eax
    ret


    
cube_r0:
    db 1,1,0,0
    db 1,1,0,0
    db 0,0,0,0
    db 0,0,0,0

; L-piece rotation 0 (standard L)
L_r0:
    db 0,0,0,0
    db 1,0,0,0
    db 1,0,0,0
    db 1,1,0,0

; L-piece rotation 1 (rotated 90° clockwise)
L_r1:
    db 0,0,0,0
    db 0,1,1,1
    db 0,1,0,0
    db 0,0,0,0

; L-piece rotation 2 (rotated 180°)
L_r2:
    db 0,0,0,0
    db 0,1,1,0
    db 0,0,1,0
    db 0,0,1,0

; L-piece rotation 3 (rotated 270°)
L_r3:
    db 0,0,0,0
    db 0,0,1,0
    db 1,1,1,0
    db 0,0,0,0



; Lookup table for shape bitmasks
shape_table:
    dd cube_r0, cube_r0, cube_r0, cube_r0      ; Cube (all rotations same)
    dd L_r0, L_r1, L_r2, L_r3                  ; L-piece rotations
    
draw_l_index:
    pushad
    add ebx, 1
    mov ecx, 3
    mov edx, 3
    mov esi, 6
    call mode13_fill_rect
	popad
    ret
    
draw_L:
	; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    pushad
 	call draw_l_index
 	add ebx, 4
 	call draw_l_index
 	add ebx, 4
 	call draw_l_index
 	add eax, 4
 	call draw_l_index


	popad
    ret
exterminate_L:
	; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color

    pushad
    mov ecx, 4
    mov edx, 16
    mov esi, 0
    call mode13_fill_rect
    add ebx, 12
    mov ecx, 8
    mov edx, 4
    mov esi, 0
    call mode13_fill_rect

	popad
    ret
erase_block:
    ; Input: EAX = x, EBX = y
    pushad
    mov ecx, 8
    mov edx, 8
    mov esi, 0
    call mode13_fill_rect
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

SHAPE_CUBE  equ 1
SHAPE_L     equ 0
current_shape_type  db 0
current_rotation    db 0
temp_shape_ptr dd 0

string_x dd 0
string_y dd 0
string_color db 0
score_text db 'SCORE', 0
lines_text db 'LINES', 0
level_text db 'LEVEL', 0
next_text  db 'NEXT', 0

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
