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

    
 .block_loop:
    cmp byte [game_running], 0
    je .paused
    
    mov eax, 6
    call wait_frames
    
    ; Erase old position
    mov eax, [last_drawn_x]
    mov ebx, [last_drawn_y]
    call erase_block
    
	call refresh_index
	
    ; CHECK COLLISION BEFORE MVING
    mov eax, [current_y_index]
    inc eax                     
    cmp eax, 19                  ; no more rows?
    jge .bottom_block            ; Hit floor
    
    ; Check at (x_index, y_index+1)
    imul eax, 10
    add eax, [current_x_index]
    cmp byte [tetris_grid + eax], 0
    jne .bottom_block         
    
    ; Safe to move 
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    add ebx, 8
    mov [current_piece_y], ebx
    mov [last_drawn_x], eax
    mov [last_drawn_y], ebx

    
    ; Draw at new position
    call draw_block
    jmp .block_loop
    

    
.bottom_block:
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    call draw_block
    
    call refresh_index
    
    ; Get indices
    mov eax, [current_y_index]
    mov ebx, [current_x_index]
    
    ; STORE FIRST OMG
    push eax
    push ebx
    imul eax, 10
    add eax, ebx
    mov byte [tetris_grid + eax], 1
    pop ebx
    pop eax
    

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
    
    mov dword [current_piece_y], 20	
    

    mov [last_drawn_x], eax
    mov dword [last_drawn_y], 20
    
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    call draw_block

    
    jmp .block_loop

.paused:
	pushad						 ; probable register corruption if I dont push/pop for some reason...
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
    popad
    jmp .game
    
refresh_index:
	pushad	

    mov eax, [current_piece_x]
    sub eax, 120			 ; offset from playfield top
    xor edx, edx
    mov ecx, 8
    div ecx
    mov [current_x_index], eax

    mov eax, [current_piece_y]
    sub eax, 20              ; offset from playfield top
    xor edx, edx
    mov ecx, 8
    div ecx                  ; eax = actual y index from where block is drawn
    mov [current_y_index], eax
    popad
    ret

check_line_complete:
	push eax
    imul eax, 10         
    mov ecx, 10          
    lea edi, [tetris_grid + eax]
    
.check_loop:
    cmp byte [edi], 0
    je .not_complete     ; empty index
    inc edi
    dec ecx
    jnz .check_loop
    
	pop eax
    mov [current_y_index], eax
    call extermish_line
	call forget_and_drop
	call clear_playfield
	call redraw_dropped
	ret
    
.not_complete:
    pop eax
    ret


; Input: eax = y index of cleared line
forget_and_drop:
    pushad
    
    ; First, clear the line
    push eax
    imul eax, 10
    mov ecx, 10
    lea edi, [tetris_grid + eax]
.clear_loop:
    mov byte [edi], 0
    inc edi
    dec ecx
    jnz .clear_loop
    pop eax                   ; eax = cleared y index
    
    ; shift all rows above down
    mov esi, eax              ; start from cleared
    
.shift_rows:
    test esi, esi             ; If esi = 0, we at da top
    jz .done
    
    
    mov eax, esi
    dec eax                   
    imul eax, 10
    lea edi, [tetris_grid + eax]  
    
    mov eax, esi
    imul eax, 10
    lea ebx, [tetris_grid + eax]  ; Dest
    
    mov ecx, 10
.copy_loop:
    mov al, [edi]
    mov [ebx], al
    inc edi
    inc ebx
    dec ecx
    jnz .copy_loop
    
    dec esi
    jmp .shift_rows
    
.done:
	lea edi, [tetris_grid]
    mov ecx, 10
    xor al, al
.clear_top:
    mov [edi], al
    inc edi
    dec ecx
    jnz .clear_top
    
    popad
    ret
    
; REMINDER: when we use 0-x dont forget the 0 as a value as well, no more off-by-1 bugs!!
; dont trust the incrementor...
;variables
tetris_grid: times 190 db 0  ; 19 rows (0-18) × 10 columns

current_x_index	   dd 4		; signed integer to track from the middle index (0-9)
current_y_index	   dd 0		; signed integer to track the y index (0-18)
current_piece_y    dd 0
current_piece_x    dd 0
last_drawn_x    dd 160
last_drawn_y    dd 22
