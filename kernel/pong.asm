pong:
    mov esp, 0x7000
    mov al, 0
    call mode13_clear_screen
    mov dword [bounces], 0
	call draw_border
	mov eax, 160
	mov ebx, 5
	mov dl, 15
	mov esi, PONG
	call mode13_print_string
	mov eax, 20
	mov ebx, 5
	mov dl, 15
	mov esi, player1
	call mode13_print_string
	mov ebx, 13
	mov dl, 15
	mov esi, player2
	call mode13_print_string
	call draw_paddle.p2
	call draw_paddle.p1


.main_loop:
    cmp byte [game_running], 0
    je .paused
	; ======= i gotta make a function outta that mumbo jumbo but i cba...=====
	mov eax, [player_1]
	call int_to_string
	mov eax, 100
	mov ebx, 5
	mov ecx, 16
	mov edx, 8
	mov esi, 0
	call mode13_fill_rect
	mov eax, 100
	mov ebx, 5
	mov dl, 15
	mov esi, dword [int_result]
	call mode13_print_string
	mov eax, [player_2]
	call int_to_string
	mov eax, 100
	mov ebx, 13
	mov ecx, 16
	mov edx, 8
	mov esi, 0
	call mode13_fill_rect
	mov eax, 100
	mov ebx, 13
	mov dl, 15
	mov esi, dword [int_result]
	call mode13_print_string
	; ======= i gotta make a function outta that mumbo jumbo but i cba...=====
	
    mov eax, 2
    call wait_frames
	call ball_logic
	
.player_loop:
    ; Check player 1 keys
    cmp byte [a_pressed], 1
    jne .check_d
    mov eax, [p1_x]
    cmp eax, 25
    jle .check_d
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
    mov eax, [p1_x]
    add eax, 50
    cmp eax, 295
    jge .player_loop_end
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
    mov eax, [p2_x]
    cmp eax, 25
    jle .player_loop_end
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
    mov eax, [p2_x]
    add eax, 55
    cmp eax, 295
    jge .player_loop_end
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

.paused:
    ; Draw pause text
    mov esi, pause_str
    mov eax, 140
    mov ebx, 90
    mov dl, 15
    call mode13_print_string
    
.pause_wait:
    hlt
    cmp byte [game_running], 1
    jne .pause_wait
    
    ; Erase pause text
    mov eax, 140
    mov ebx, 90
    mov ecx, 60
    mov edx, 20
    mov esi, 0
    call mode13_fill_rect
    jmp .main_loop

	
ball_logic:
	cmp dword [bounces], 3
	jge .speed_up

	; erase old blal
	mov eax, dword [ball_x]
	mov ebx, dword [ball_y]
	mov ecx, 4
	mov esi, 0
	call mode13_pong

.wall_check:
	mov ebx, dword [ball_y]
	add ebx, dword [ball_dy]
	cmp ebx, 24
	jle .point2
	cmp ebx, 174
	jge .point1
	
	mov ebx, dword [ball_x]
	add ebx, dword [ball_dx]
	cmp ebx, 23
	jle .negate
	cmp ebx, 293
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
    	mov eax, 720				; player 1 sound
	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone
	inc dword [bounces]
    jmp .update_position  ; skip p2 

.check_p2:

    mov ebx, dword [ball_y]
    add ebx, dword [ball_dy]  
    add ebx, 3
    
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
    	mov eax, 800
	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone
	inc dword [bounces]
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

.negate:
	neg dword [ball_dx]
	mov eax, 600
	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone
	jmp .update_position

.speed_up:
	mov eax, 0
	call change_speed
	ret
	
.point1:
	mov dword [bounces], 0
	mov eax, 1
	call change_speed
	
	inc dword [player_1]
	neg dword [ball_dx]
	neg dword [ball_dy]
	mov dword [ball_x], 160
	mov dword [ball_y], 100
	mov eax, dword [ball_x]
	mov ebx, dword [ball_y]
	mov esi, 15
	call mode13_pong
	
	mov eax, 1200
	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone				; FUCK do not forget to stop the tone, otherwise your ears bleed
	
    mov eax, 20 	; intentional double delay to make it slower and easier to react to a score
    call wait_frames
	call pong.main_loop

.point2:
	mov dword [bounces], 0
	mov eax, 1
	call change_speed
	
	inc dword [player_2]
	neg dword [ball_dy]
	neg dword [ball_dx]
	mov dword [ball_x], 160
	mov dword [ball_y], 100
	mov eax, dword [ball_x]
	mov ebx, dword [ball_y]
	mov esi, 15
	call mode13_pong
	mov eax, 1400
	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone
    mov eax, 20 	; intentional double delay to make it slower and easier to react to a score
    call wait_frames
	call pong.main_loop


change_speed:
    cmp eax, 1
    je .slow_down
    
.speed_up:

    mov eax, dword [ball_dx]
    test eax, eax
    js .speed_dx_neg
    inc dword [ball_dx]
    jmp .speed_check_dy
.speed_dx_neg:
    dec dword [ball_dx]
    
.speed_check_dy:

    mov eax, dword [ball_dy]
    test eax, eax
    js .speed_dy_neg
    inc dword [ball_dy]
    jmp .done
.speed_dy_neg:
    dec dword [ball_dy]
    jmp .done
    
.slow_down:
    ; Handle ball_dx
    mov eax, dword [ball_dx]
    test eax, eax
    js .slow_dx_neg
    cmp dword [ball_dx], 1
    jle .done
    dec dword [ball_dx]
    jmp .slow_check_dy
.slow_dx_neg:
    cmp dword [ball_dx], -1
    jle .done
    inc dword [ball_dx]
    
.slow_check_dy:

    mov eax, dword [ball_dy]
    test eax, eax
    js .slow_dy_neg
    cmp dword [ball_dy], 1
    jle .done
    dec dword [ball_dy]
    jmp .done
.slow_dy_neg:
    cmp dword [ball_dy], -1
    jle .done
    inc dword [ball_dy]
.done:
    mov dword [bounces], 0
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

player_1		dd 0
player_2		dd 0
bounces 		  dd 0
p1_x			  dd 160
p1_y			  dd 25
p2_x			  dd 160
p2_y			  dd 170

player1		  db 'PLAYER 1', 0
player2		  db 'PLAYER 2', 0
ball_x		  dd 160
ball_y		  dd 100
ball_dx		  dd 2	    ; baller speed
ball_dy		  dd 2			; 
