pong:
    mov esp, 0x7000
    mov al, 0
    call mode13_clear_screen
	mov eax, 50
	mov ebx, 50
	mov ecx, 2
	mov esi, 15
	call mode13_pong
	call draw_paddle.p1
	call draw_paddle.p2

.player_loop:
    mov eax, 2
    call wait_frames
    
    ; Check player 1 keys
    cmp byte [a_pressed], 1
    jne .check_d
    ; erase old p1 position
    mov eax, [p1_x]
    mov ebx, [p1_y]
    mov ecx, 50
    mov edx, 5
    mov esi, 0
    call mode13_fill_rect
    sub dword [p1_x], 5
    call draw_paddle.p1
    
.check_d:
    cmp byte [d_pressed], 1
    jne .check_p2_left
    ; erase old p1 position
    mov eax, [p1_x]
    mov ebx, [p1_y]
    mov ecx, 50
    mov edx, 5
    mov esi, 0
    call mode13_fill_rect
    add dword [p1_x], 5
    call draw_paddle.p1
    
.check_p2_left:
    cmp byte [left_pressed], 1
    jne .check_p2_right
    ; erase 
    mov eax, [p2_x]
    mov ebx, [p2_y]
    mov ecx, 50
    mov edx, 5
    mov esi, 0
    call mode13_fill_rect
    sub dword [p2_x], 5
    call draw_paddle.p2
    
.check_p2_right:
    cmp byte [right_pressed], 1
    jne .player_loop_end
    ; erase 
    mov eax, [p2_x]
    mov ebx, [p2_y]
    mov ecx, 50
    mov edx, 5
    mov esi, 0
    call mode13_fill_rect
    add dword [p2_x], 5
    call draw_paddle.p2

.player_loop_end:
	jmp .player_loop



draw_paddle:
.p1:
    mov eax, [p1_x]
    mov ebx, [p1_y]
    mov ecx, 50
    mov edx, 5
    mov esi, 15
    call mode13_fill_rect
	ret

.p2:
    mov eax, [p2_x]
    mov ebx, [p2_y]
    mov ecx, 50
    mov edx, 5
    mov esi, 15
    call mode13_fill_rect
	ret
    
player		db 0

p1_x		dd 160
p1_y		dd 5
p2_x		dd 160
p2_y		dd 175
