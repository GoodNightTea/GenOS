pong:
    mov esp, 0x7000
    mov al, 0
    call mode13_clear_screen
	call draw_paddle.p2
	call draw_paddle.p1


.main_loop:
    mov eax, 2
    call wait_frames
	call ball_logic
	
.player_loop:
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
	jmp .main_loop

ball_logic:
	; erase old blal
	mov eax, dword [ball_x]
	mov ebx, dword [ball_y]
	mov ecx, 2
	mov esi, 0
	call mode13_pong

.wall_check:
	mov ebx, dword [ball_x]
	add ebx, dword [ball_dx]
	cmp ebx, 2
	jle .negate
	cmp ebx, 318
	jge .negate

.collision_check:

    mov ebx, dword [ball_y]
    add ebx, dword [ball_dy] 
    
    mov ecx, dword [p1_y]
    add ecx, 5  
    cmp ebx, ecx
    jge .check_p2  
    
    mov ecx, dword [p1_y]
    cmp ebx, ecx
    jl .check_p2  
    

    mov eax, dword [ball_x]
    add eax, dword [ball_dx]
    
    mov ecx, dword [p1_x]
    add ecx, 50  
    cmp eax, ecx
    jge .check_p2
    
    mov ecx, dword [p1_x]
    cmp eax, ecx
    jl .check_p2

    neg dword [ball_dy]
    jmp .update_position  ; skip p2 
.negate:
	neg dword [ball_dx]
	jmp .update_position
.check_p2:

    mov ebx, dword [ball_y]
    add ebx, dword [ball_dy]  
    add ebx, 2  
    
    mov ecx, dword [p2_y]
    cmp ebx, ecx
    jl .update_position  
    
    mov ecx, dword [p2_y]
    add ecx, 5
    cmp ebx, ecx
    jge .update_position 
    

    mov eax, dword [ball_x]
    add eax, dword [ball_dx]
    
    mov ecx, dword [p2_x]
    add ecx, 50
    cmp eax, ecx
    jge .update_position
    
    mov ecx, dword [p2_x]
    cmp eax, ecx
    jl .update_position
    

    neg dword [ball_dy]
    
.update_position:
	mov eax, dword [ball_x]
	add eax, dword [ball_dx]	
	mov dword [ball_x], eax
	mov ebx, dword [ball_y]
	add ebx, dword [ball_dy]
	mov dword [ball_y], ebx
	mov esi, 15
	call mode13_pong
	ret
draw_paddle:
.p1:
	; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
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

ball_x		dd 100
ball_y		dd 100
ball_dx		dd 1	    ; baller speed
ball_dy		dd 1			; 
