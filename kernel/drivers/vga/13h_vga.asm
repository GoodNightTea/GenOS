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
print_cool_string:
    pushad
    mov [string_x], eax
    mov [string_y], ebx
    mov [string_color], dl
    mov [string_ptr], esi
    
.next_char:
	push eax 		; uncertain as to why, but I cannot add a delay inside of the regular print_string due to timing inconsitencies in the main menu
    mov eax, 1
    call wait_frames
    pop eax
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
    lea edi, [font1_data + edi]
    
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

; ----------------------------------------------------------------------------
; Input: ESI = pointer to null-terminated string only uppercase
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
	;push eax
    ;mov eax, 1
    ;call wait_frames
    ;pop eax
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
    lea edi, [font1_data + edi]
    
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
; Input: ESI = pointer to null-terminated string only uppercase
;
;        EAX = x position, EBX = y position, DL = color
; ----------------------------------------------------------------------------
font2_string:
    pushad
    mov [string_x], eax
    mov [string_y], ebx
    mov [string_color], dl
    mov [string_ptr], esi
    
.next_char:
	;push eax
    ;mov eax, 1
    ;call wait_frames
    ;pop eax
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
    lea edi, [font2_data + edi]
    
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
    
    ; Calculate starting address: y * 320 + x
    mov eax, ebx               ; y
    imul eax, MODE13_WIDTH     ; y * 320
    add eax, [m13_rect_x]      ; + x (assuming you meant to use parameter not variable)
    add eax, MODE13_BUFFER     ; + base address
    mov edi, eax               ; EDI = starting address
    
	mov eax, esi
	and eax, 0xFF  ; mask to get just the low byte
    
    xor ebx, ebx               ; row counter
.row_loop:
    cmp ebx, edx               ; compare with height
    jge .done
    
    push edi                   ; save row start address
    mov ecx, [m13_rect_width]  ; or just ECX if width is in ECX param
    rep stosb                  ; fill entire row in one go
    pop edi
    
    add edi, MODE13_WIDTH      ; move to next scanline
    inc ebx
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
; draw_gradient_rect: draws a gradient rectangle with with a ranging gradient scale
; Input: EAX = x, EBX = y, ECX = width, EDX = height
;   [grad_start_idx] = first palette index to use
;   [grad_end_idx] = last palette index to use
; ----------------------------------------------------------------------------


draw_gradient_rect:
    pushad
    
    mov [grad_x], eax
    mov [grad_y], ebx
    mov [grad_width], ecx
    mov [grad_height], edx
    
    ; Calculate palette range
    mov eax, [grad_end_idx]
    sub eax, [grad_start_idx]
    mov [grad_range], eax           ; Number of colors available
    
    xor ebp, ebp                    ; Row counter
    
.row_loop:
    cmp ebp, [grad_height]
    jge .done
    
    xor esi, esi                    ; Column counter
    
.col_loop:
    cmp esi, [grad_width]
    jge .next_row
    

    ; index = start + (column * range) / width
    mov eax, esi
    mul dword [grad_range]          ; EDX:EAX = column * range
    div dword [grad_width]          ; EAX = (column * range) / width
    add eax, [grad_start_idx]       ; Add start offset
    
    ; Clamp to end index (safety)
    cmp eax, [grad_end_idx]
    jle .in_range
    mov eax, [grad_end_idx]
.in_range:
    
    ; Draw pixel
    push eax                        ; Save color
    mov eax, [grad_x]
    add eax, esi
    mov ebx, [grad_y]
    add ebx, ebp
    pop ecx                         ; Color index
    call mode13_set_pixel
    
    inc esi
    jmp .col_loop
    
.next_row:
    inc ebp
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
; Gradient setups - created with the help of generative AI
; ============================================================================

; Grayscale in 16-47
setup_grayscale_palette:
    pushad
    xor edi, edi
.loop:
    cmp edi, 32
    jge .done
    
    mov eax, edi
    mov edx, 63
    mul edx
    mov ebx, 31
    xor edx, edx
    div ebx                         ; Intensity
    
    mov ebx, eax                    ; R=G=B
    mov ecx, eax
    mov eax, edi
    add eax, 16                     ; Index 16-47
    mov bh, bl
    call setup_grayscale_palette
    
    inc edi
    jmp .loop
.done:
    popad
    ret

; Rainbow in 48-79
setup_rainbow_palette:
    pushad
    xor edi, edi
.loop:
    cmp edi, 32
    jge .done
    

    ; Hue varies from 0-360 degrees
    mov eax, edi
    mov edx, 360
    mul edx
    mov ebx, 32
    div ebx                         ; EAX = hue (0-360)
    

    cmp eax, 120
    jl .red_to_green
    cmp eax, 240
    jl .green_to_blue
    ; blue_to_red
    sub eax, 240
    mov ebx, 63                     ; Red increases
    mul ebx
    mov ecx, 120
    div ecx
    mov ebx, eax
    mov ecx, 63
    sub ecx, eax                    ; Blue decreases
    xor eax, eax                    ; Green = 0
    jmp .set
    
.red_to_green:
    mov ebx, 63                     ; Red = max
    mov edx, eax
    mov eax, 63
    mul edx
    mov ecx, 120
    div ecx                         ; Green increases
    mov [temp_g], al
    mov ecx, 0                      ; Blue = 0
    mov al, [temp_g]
    mov bh, al
    jmp .set
    
.green_to_blue:
    sub eax, 120
    xor ebx, ebx                    ; Red = 0
    mov edx, 63
    sub edx, eax
    mov bh, dl                      ; Green decreases
    mov ecx, eax                    ; Blue increases
    
.set:
    push ebx
    push ecx
    mov eax, edi
    add eax, 48                     ; Index 48-79
    pop ecx
    pop ebx
    call set_palette_color
    
    inc edi
    jmp .loop
.done:
    popad
    ret


setup_gradient_palette:
    pushad
    
    xor edi, edi                    ; Counter: 0-31
    
.loop:
    cmp edi, 32
    jge .done
    
    ; Calculate intensity: (counter * 63) / 31
    mov eax, edi
    mov edx, 63
    mul edx                         ; EDX:EAX = counter * 63
    mov ebx, 31
    div ebx                         ; EAX = intensity (0-63)
    
    ; Palette index = 16 + counter
    mov ebx, edi
    add ebx, 16
    
    ; Set palette entry
    push eax                        ; Save intensity
    push ebx                        ; Save index
    
    mov al, bl                      ; AL = palette index
    pop ebx                         ; Get index back
    pop ebx                         ; Get intensity
    
    ; Set R=G=B=intensity for grayscale
    mov bl, bl                      ; Red = intensity (already in BL)
    mov bh, bl                      ; Green = intensity
    mov cl, bl                      ; Blue = intensity
    
    push edi
    call set_palette_color
    pop edi
    
    inc edi
    jmp .loop
    
.done:
    popad
    ret
 
set_palette_color:
    ; Input: AL = index, BL = red (0-63), BH = green (0-63), CL = blue (0-63)
    push eax
    push ebx
    push ecx
    push edx
    
    ; Select palette index
    mov dx, 0x03C8
    out dx, al
    
    ; Write RGB values
    mov dx, 0x03C9
    mov al, bl              ; Red
    out dx, al
    mov al, bh              ; Green
    out dx, al
    mov al, cl              ; Blue
    out dx, al
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
; ============================================================================
; DATA SECTION FOR 13h VGA DRIVER
; ============================================================================
temp_g: db 0
grad_x:         dd 0
grad_y:         dd 0
grad_width:     dd 0
grad_height:    dd 0
grad_start_idx: dd 16               
grad_end_idx:   dd 47
grad_range:     dd 0

m13_rect_x:      dd 0
m13_rect_y:      dd 0
m13_rect_width:  dd 0
m13_rect_height: dd 0
m13_rect_color:  dd 0


color			 dd 0
string_x 		 dd 0
string_y 		 dd 0
string_color 	 db 0

