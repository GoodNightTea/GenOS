; will try to create a bitmap logo, consisting of a 16x16 bitmap 
logo_data:
	; 16x16 G
    dw 0b0001111111111000
    dw 0b0011000000001100
    dw 0b0110000000001100
    dw 0b1100000000000110
    dw 0b1100000000000110
    dw 0b1100000000000000
    dw 0b1100000000000000
    dw 0b1100011111111110
    dw 0b1100011000000110
    dw 0b1100011000000110
    dw 0b1100011000000110
    dw 0b1100000000000110
    dw 0b1100000000000110
    dw 0b1100000000001100
    dw 0b0110000000011000
    dw 0b0011111111110000

	; 16x16 e
    dw 0b0000000000000000 ;1
    dw 0b0000000000000000 ;2
    dw 0b0000000000000000 ;3
    dw 0b0000000000000000 ;4
    dw 0b0000000000000000 ;5
    dw 0b0000000000000000 ;6
    dw 0b0000000000000000 ;7
    dw 0b0011111111110000 ;8
    dw 0b0110000000011000 ;9
    dw 0b1100000000001100 ;10
    dw 0b1111111111111100 ;11
    dw 0b1000000000000000 ;12
    dw 0b1100000000000000 ;13
    dw 0b1100000000000110 ;14
    dw 0b0110000000001100 ;15
    dw 0b0011111111111000 ;16

	; 16x16 n
    dw 0b0000000000000000 ;1
    dw 0b0000000000000000 ;2
    dw 0b0000000000000000 ;3
    dw 0b0000000000000000 ;4
    dw 0b0000000000000000 ;5
    dw 0b0000000000000000 ;6
    dw 0b0000000000000000 ;7
    dw 0b0111111111100000 ;8
    dw 0b0110000000110000 ;9
    dw 0b0110000000110000 ;10
    dw 0b0110000000011000 ;11
    dw 0b0110000000011000 ;12
    dw 0b0110000000011000 ;13
    dw 0b0110000000011000 ;14
    dw 0b0110000000011000 ;15
    dw 0b0110000000011000 ;16

	; 16x16 O
    dw 0b0000111111100000 ;1
    dw 0b0011000000011000 ;2
    dw 0b0110000000001100 ;3
    dw 0b1100000000000110 ;4
    dw 0b1100000000000110 ;5
    dw 0b1100000000000110 ;6
    dw 0b1100000000000110 ;7
    dw 0b1100000000000110 ;8
    dw 0b1100000000000110 ;9
    dw 0b1100000000000110 ;10
    dw 0b1100000000000110 ;11
    dw 0b1100000000000110 ;12
    dw 0b1100000000000110 ;13
    dw 0b0110000000001100 ;14
    dw 0b0011000000011000 ;15
    dw 0b0000111111100000 ;16

	; 16x16 S
    dw 0b0000111111100000 ;1
    dw 0b0011000000011000 ;2
    dw 0b0110000000001100 ;3
    dw 0b1100000000000000 ;4
    dw 0b1100000000000000 ;5
    dw 0b0110000000000000 ;6
    dw 0b0011000000000000 ;7
    dw 0b0000111111100000 ;8
    dw 0b0000000000011000 ;9
    dw 0b0000000000001100 ;10
    dw 0b0000000000000110 ;11
    dw 0b0000000000000110 ;12
    dw 0b1100000000000110 ;13
    dw 0b0110000000001100 ;14
    dw 0b0110000000001100 ;15
    dw 0b0001111111110000 ;16
    
print_LOGO:
    pushad
    mov [logo_x], eax
    mov [logo_y], ebx
    mov [logo_color], dl
    
    xor esi, esi                    ; Character counter (0-4 for G, e, n, O, S)
    
.next_char:
	mov dl, [logo_color]
	add dl, 1
    mov [logo_color], dl						; first char diff color
    cmp esi, 5                      ; 5 characters total
    jge .done
    
    ; Calculate offset: char_index * 16 rows * 2 bytes
    mov eax, esi
    shl eax, 5                      ; * 32 bytes per character (16 rows × 2 bytes)
    lea edi, [logo_data + eax]
    
    xor ebp, ebp                    ; Row counter
    
.row_loop:
    cmp ebp, 16
    jge .char_done
    
    ; Load 16-bit row
    movzx eax, word [edi]
    add edi, 2                      ; Move to next row
    
    xor ecx, ecx                    ; Column counter
    
.col_loop:
    cmp ecx, 16
    jge .next_row
    
    ; Test bit from MSB (bit 15 down to 0)
    mov edx, 15
    sub edx, ecx
    bt ax, dx                       ; Test bit at position EDX
    jnc .skip_pixel                 ; Skip if bit not set
    
    ; Draw pixel
    push eax
    push ecx
    push ebp
    push esi
    
    mov eax, [logo_x]
    add eax, ecx                    ; + column
    mov ebx, esi
    shl ebx, 4                      ; char_index * 16
    add eax, ebx                    ; Spacing between characters
    
    mov ebx, [logo_y]
    add ebx, ebp                    ; + row
    
    mov cl, [logo_color]
    call mode13_set_pixel
    
    pop esi
    pop ebp
    pop ecx
    pop eax
    
.skip_pixel:
    inc ecx
    jmp .col_loop
    
.next_row:
    inc ebp
    jmp .row_loop
    
.char_done:

    inc esi
    jmp .next_char
    
.done:
    popad
    ret

logo_x:     dd 0
logo_y:     dd 0
logo_color: db 0
