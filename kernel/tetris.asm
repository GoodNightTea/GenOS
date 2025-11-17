tetris_setup:
    mov al, 0
    call mode13_clear_screen
    call draw_hud
    
    mov esp, 0x7000
    
.game:
    cmp byte [game_running], 0
    je .paused
    
    mov eax, 5
    call wait_frames
    mov dword [current_piece_y], 20
    mov dword [current_piece_x], 160
    mov dword [current_x_index], 4
    mov dword [current_y_index], 0
    jmp .block_loop
.paused:
    mov esi, paused         	 ; Point to string
	mov eax, 130                 ; X position
	mov ebx, 80                	 ; Y position
	mov dl, 75                  ; White color
	call mode13_print_string
	
.pause_loop:
    hlt                              
    cmp byte [game_running], 1       
    jne .pause_loop
    mov eax, 130
    mov ebx, 80
    mov ecx, 60
    mov edx, 8
    mov esi, 0x00
    call mode13_fill_rect
    jmp .game
    
 .block_loop:
    cmp byte [game_running], 0
    je .paused
    
    mov eax, 6
    call wait_frames
    

    mov eax, [last_drawn_x]
    mov ebx, [last_drawn_y]
    call erase_block
    

    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    

    add ebx, 8
    
    ; Check if would hit bottom
    cmp ebx, 172              ; Would go past 164
    jge .bottom_block
    
    ; Update position
    mov [current_piece_y], ebx
    mov [last_drawn_x], eax
    mov [last_drawn_y], ebx
    
    ; Draw at new position
    call draw_block
    
    jmp .block_loop

.bottom_block:
    ; Draw at CURRENT valid position (before inc of next index)
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    call draw_block
    
    ; Calculate Y index from CURRENT position
    mov eax, [current_piece_y]
    sub eax, 20
    xor edx, edx
    mov ecx, 8
    div ecx              ; eax = y_index (0-18)
    
    ; Get X index
    mov ebx, [current_x_index]
	    
	; Save Y index for line check
	mov dword [current_y_index], eax
	
    ; Calculate offset: y_index * 10 + x_index
    imul eax, 10
    add eax, ebx
    
    ; Mark as filled
    mov byte [tetris_grid + eax], 1
    
    ; Check line 
    mov eax, dword [current_y_index]
    call check_line_complete
    
    jmp .next_block

.next_block:
    ; Reset grid index to center
    mov dword [current_x_index], 4
    
    ; Calculate pixel position from index
    mov eax, 4
    imul eax, 8
    add eax, 120
    mov [current_piece_x], eax
    
    mov dword [current_piece_y], 20		; Set Y to top   
    
   				 						; Initialize last_drawn to same position
    mov [last_drawn_x], eax
    mov dword [last_drawn_y], 20
    
    ; Draw first block
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    call draw_block
    
    jmp .block_loop

check_line_complete:
    mov eax, dword [current_y_index]
    push eax             ; idk if its necessary but i dont wanna loose it
    
    imul eax, 10         ; Start of row
    mov ecx, 10          ; Check 10 columns
    lea edi, [tetris_grid + eax]
    
.check_loop:
    cmp byte [edi], 0
    je .not_complete     ; Found empty cell
    inc edi
    dec ecx
    jnz .check_loop
    
    ; Line is complete!
    mov esi, line_sniffed
    mov eax, 130
    mov ebx, 80
    mov dl, 100
    call mode13_print_string
    pop eax
    ret
    
.not_complete:
    pop eax
    ret


    
; REMINDER: when we use 0-x dont forget the 0 as a value as well, no more off-by-1 bugs!!
;variables
tetris_grid: times 190 db 0  ; 19 rows (0-18) × 10 columns

current_x_index	   dd 4		; signed integer to track from the middle index (0-9)
current_y_index	   dd 0		; signed integer to track the y index (0-18)
current_piece_y    dd 0
current_piece_x    dd 0
last_drawn_x    dd 160
last_drawn_y    dd 22
line_sniffed			  db 'YEA', 0
