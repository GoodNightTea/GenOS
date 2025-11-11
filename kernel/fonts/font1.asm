; the most beautiful and advanced font (idk if you can call a bitmap from 0-9 a font but yea shush)
font_data:
    ; Character '0'
    db 0b00111100
    db 0b01000010
    db 0b01000110
    db 0b01001010
    db 0b01010010
    db 0b01100010
    db 0b00111100
    db 0b00000000
    
    ; Character '1'
    db 0b00011000
    db 0b00101000
    db 0b01001000
    db 0b00001000
    db 0b00001000
    db 0b00001000
    db 0b00111110
    db 0b00000000
    
    ; Character '2'
    db 0b01111000
    db 0b10000100
    db 0b00001000
    db 0b00010000
    db 0b00100000
    db 0b01000000
    db 0b11111110
    db 0b00000000
    
    ; Character '3'
    db 0b01111000
    db 0b00000100
    db 0b00000100
    db 0b00011000
    db 0b00000100
    db 0b00000100
    db 0b01111000
    db 0b00000000
    ; Character '4'
    db 0b00001100
    db 0b00010100
    db 0b00100100
    db 0b01000100
    db 0b11111100
    db 0b00000100
    db 0b00000100
    db 0b00000000
    ; Character '5'
    db 0b01111100
    db 0b01000000
    db 0b01111000
    db 0b00000100
    db 0b00000010
    db 0b00000010
    db 0b01111100
    db 0b00000000
    ; Character '6'
    db 0b01111000
    db 0b10000000
    db 0b10111000
    db 0b11000100
    db 0b10000100
    db 0b10000100
    db 0b01111000
    db 0b00000000
    ; Character '7'
    db 0b01111110
    db 0b00000010
    db 0b00000100
    db 0b00001000
    db 0b00010000
    db 0b00100000
    db 0b01000000
    db 0b00000000
    
    ; Character '8'
    db 0b01111100
    db 0b10000010
    db 0b10000010
    db 0b01111100
    db 0b10000010
    db 0b10000010
    db 0b01111100
    db 0b00000000
    ; Character '9'
    db 0b01111100
    db 0b10000010
    db 0b10000010
    db 0b01111100
    db 0b00000010
    db 0b00000010
    db 0b01111100
    db 0b00000000
draw_char:
    ; EAX = x, EBX = y, CL = ASCII char, DL = color
    pushad
    
    ; Save original X and Y in safe places
    mov [char_x], eax
    mov [char_y], ebx
    mov [char_color], dl
    
    ; Calculate font offset (char * 8 bytes)
    sub cl, '0'
    movzx esi, cl
    shl esi, 3
    lea esi, [font_data + esi]
    
    ; Draw 8×8 bitmap
    xor edi, edi               ; Row counter
.row_loop:
    cmp edi, 8
    jge .done
    
    lodsb                      ; Load row bitmap into AL
    push eax                   ; Save the row bitmap
    
    xor ecx, ecx               ; Column counter
.col_loop:
    cmp ecx, 8
    jge .next_row
    
    ; Test bit at position (7 - column)
    mov eax, [esp]             ; Get row bitmap from stack
    mov edx, 7
    sub edx, ecx
    push ecx
    mov cl, dl
    shr eax, cl                ; Shift to test bit
    pop ecx
    
    test al, 1                 ; Test bit 0
    jz .skip_pixel
    
    ; Draw pixel at (char_x + column, char_y + row)
    push ecx
    push edi
    mov eax, [char_x]
    add eax, ecx               ; X + column
    mov ebx, [char_y]
    add ebx, edi               ; Y + row
    mov cl, [char_color]
    call mode13_set_pixel
    pop edi
    pop ecx
    
.skip_pixel:
    inc ecx
    jmp .col_loop
    
.next_row:
    pop eax                    ; Clean up row bitmap
    inc edi
    jmp .row_loop
    
.done:
    popad
    ret


char_x:     dd 0
char_y:     dd 0
char_color: db 0
