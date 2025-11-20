tetris_setup:
    mov al, 0
    call mode13_clear_screen
    call draw_hud
    
    mov esp, 0x7000
	
    
.game:
    cmp byte [game_running], 0
    je .paused
    mov dword [color], 10 
    mov eax, 5
    call wait_frames
    
    call spawn_next_piece    ; ← Just call, don't reset next_shape_type
    jmp .block_loop

    
 .block_loop:
    cmp byte [game_running], 0
    je .paused
.hud:
    pushad
    call draw_hud
    mov eax, 50
	mov ebx, 30
    mov ecx, 16
    mov edx, 8
    mov esi, 0x00
    call mode13_fill_rect
	mov eax, [score]
	call int_to_string            
    mov esi, [int_result]
    
    mov eax, 50
	mov ebx, 30
	mov dl, 0x0F
	call mode13_print_string
	popad
.debug:
	pushad
    mov eax, 300
	mov ebx, 30
    mov ecx, 16
    mov edx, 8
    mov esi, 0x00
    call mode13_fill_rect
    mov eax, dword [current_x_index]
    call int_to_string
    mov esi, [int_result]
    mov eax, 300
	mov ebx, 30
	mov dl, 0x0F
	call mode13_print_string
    popad
	pushad
    mov eax, 300
	mov ebx, 38
    mov ecx, 16
    mov edx, 8
    mov esi, 0x00
    call mode13_fill_rect
    mov eax, dword [current_y_index]
    call int_to_string
    mov esi, [int_result]
    mov eax, 300
	mov ebx, 38
	mov dl, 0x0F
	call mode13_print_string
    popad
    
    mov eax, 300
	mov ebx, 46
    mov ecx, 16
    mov edx, 8
    mov esi, 0x00
    call mode13_fill_rect
    mov eax, dword [speed]
    call int_to_string
    mov esi, dword [int_result]
	mov eax, 300
	mov ebx, 46
	mov dl, 0x0F
	call mode13_print_string
	mov eax, dword [speed]
    call wait_frames
    
    ; Erase old position
    mov eax, [last_drawn_x]
    mov ebx, [last_drawn_y]
    call erase_block
    call exterminate_L
	call refresh_index
	
    
    mov eax, [current_y_index]
    add eax, 3                  ; Check row below the cube
    cmp eax, 38                 ; Past bottom?
    jge .bottom_block
    
    call check_bottom_collision
	cmp eax, 0
	jne .bottom_block

    ; Safe to move 
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    add ebx, 8
    mov [current_piece_y], ebx
    mov [last_drawn_x], eax
    mov [last_drawn_y], ebx

    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    ; Draw at new position
    call draw_current_piece
    jmp .block_loop
    

    
.bottom_block:
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    call draw_current_piece
    
    call refresh_index
    
    call get_current_shape      ; ESI = bitmask pointer
    
    ; Iterate through bitmask and store occupied cells
    xor ecx, ecx                ; row counter

.row_loop:
    cmp ecx, 4
    jge .locked
    
    xor edx, edx                ; col counter

.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Calculate bitmask offset
    push ecx
    push edx
    
    mov edi, ecx
    shl edi, 2                  ; row * 4
    add edi, edx                ; + col
    
    cmp byte [esi + edi], 0
    pop edx
    pop ecx
    je .next_col                ; Skip empty cells
    
    ; This cell is occupied - store to grid
    ; Grid position = (current_x_index + col, current_y_index + row)
    
    mov eax, [current_y_index]
    mov ebx, [current_x_index]
    
    add eax, ecx                ; y_index + row offset
    add ebx, edx                ; x_index + col offset
    
    ; Store using your old pattern
    push eax
    push ebx
    imul eax, 20
    add eax, ebx
    mov byte [tetris_grid + eax], 1
    pop ebx
    pop eax

.next_col:
    inc edx
    jmp .col_loop

.next_row:
    inc ecx
    jmp .row_loop

.locked:
    call check_line_complete
    
    jmp .next_block

.next_block:
    call draw_hud
    call spawn_next_piece          ; ← Just this one line!
    
    mov eax, [current_piece_x]
    mov ebx, [current_piece_y]
    call draw_current_piece
    
    jmp .block_loop

.paused:
	pushad						 ; probable register corruption if I dont push/pop for some reason...
    push eax
    push ebx
    mov esi, paused         	 ; Point to string
	mov eax, 130                 ; X position
	mov ebx, 80                	 ; Y position
	mov dl, 75                  ; White color
	call mode13_print_string
	
.pause_loop:
    hlt
    call draw_hud
    cmp byte [game_running], 1
    jne .pause_loop
    mov eax, 130
    mov ebx, 80
    mov ecx, 60
    mov edx, 8
    mov esi, 0x00
    call mode13_fill_rect
    popad
    pop eax
    pop ebx
    jmp .game
    
refresh_index:
	pushad	

    mov eax, [current_piece_x]
    sub eax, 120			 ; offset from playfield left
    xor edx, edx
    mov ecx, 4
    div ecx
    mov [current_x_index], eax

    mov eax, [current_piece_y]
    sub eax, 20              ; offset from playfield top
    xor edx, edx
    mov ecx, 4
    div ecx                  ; eax = actual y index from where block is drawn
    mov [current_y_index], eax
    popad
    ret
check_bottom_collision:
    ; Returns: EAX = 0 if safe to move down, 1 if collision
    pushad
    
    call get_current_shape      ; ESI = bitmask
    
    ; Find the lowest occupied row for each column
    ; Then check if moving down would collide
    
    xor ecx, ecx                ; row counter
    mov byte [collision_found], 0
    
.row_loop:
    cmp ecx, 4
    jge .check_done
    
    xor edx, edx                ; col counter
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if this cell occupied
    push ecx
    push edx
    
    mov edi, ecx
    shl edi, 2
    add edi, edx
    
    cmp byte [esi + edi], 0
    pop edx
    pop ecx
    je .next_col
    
    ; This cell is occupied - check cell below it
    mov eax, [current_y_index]
    add eax, ecx                ; Current cell row
    inc eax                     ; Row below
    
    ; Floor check
    cmp eax, 38
    jge .collision_detected
    
    mov ebx, [current_x_index]
    add ebx, edx                ; Current cell col
    
    ; Check grid
    push ecx
    push edx
    imul eax, 20
    add eax, ebx
    cmp byte [tetris_grid + eax], 0
    pop edx
    pop ecx
    jne .collision_detected
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop
    
.collision_detected:
    mov byte [collision_found], 1
    
.check_done:
    popad
    movzx eax, byte [collision_found]
    ret


check_line_complete:
    mov esi, 37              ; Start from bottom row
    
.check_row:
    cmp esi, 0               ; Reached top?
    jl .done
    
    ; Check if row ESI is complete
    mov eax, esi
    imul eax, 20
    mov ecx, 20
    lea edi, [tetris_grid + eax]
    
.check_loop:
    cmp byte [edi], 0
    je .not_complete         ; Row not full, move to next
    inc edi
    dec ecx
    jnz .check_loop
    
    ; Row is full! Clear it
    inc dword [score]		; not sure what is causing it, but we are rowing through this section twice as intended...
    mov [current_y_index], esi
    call extermish_line
    mov eax, esi              ; Pass y_index in EAX
    call forget_and_drop
    call clear_playfield
    call redraw_dropped
    
    ; DON'T decrement esi - check row 37 again
    ; because new content shifted into it
    jmp .check_row
    
.not_complete:
    dec esi                  ; Move up to next row
    jmp .check_row
    
.done:
    ret


spawn_next_piece:
    ; Set current piece to the queued piece
    mov al, [next_shape_type]
    mov [current_shape_type], al
    mov byte [current_rotation], 0
    
    ; Reset position to top center
    mov dword [current_x_index], 10
    mov dword [current_y_index], 0
    
    ; Calculate pixel position
    mov eax, 10
    imul eax, 4
    add eax, 120
    mov [current_piece_x], eax
    mov dword [current_piece_y], 20
    
    mov [last_drawn_x], eax
    mov dword [last_drawn_y], 20
    
    ; Pick next piece based on what we JUST spawned
    mov al, [current_shape_type]     ; ← Check current, not next
    cmp al, SHAPE_CUBE
    je .queue_L_next
    
    ; Just spawned L, queue cube next
    mov byte [next_shape_type], SHAPE_CUBE
    ret
    
.queue_L_next:
    ; Just spawned cube, queue L next
    mov byte [next_shape_type], SHAPE_L
    ret
    
; Input: eax = y index of cleared line
forget_and_drop:
    pushad
    push eax
    imul eax, 20
    mov ecx, 20
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
    imul eax, 20
    lea edi, [tetris_grid + eax]  
    
    mov eax, esi
    imul eax, 20
    lea ebx, [tetris_grid + eax]  ; Dest
    
    mov ecx, 20
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
    mov ecx, 20
    xor al, al
.clear_top:
    mov [edi], al
    inc edi
    dec ecx
    jnz .clear_top
    
    popad
    ret
    
%if 0
uncertain how I should design the score system, maybe 1 per line? but it feels like blocks come every bluemoon due to it being slow as shit, imma add the gravity accel via S
okay so after adding this whole mumbo jumbo, I think its time to switch to heavier guns, time for complexer shapes
but lets say we create the L piece, its normally start 0/0 4x 16y and start 4/12 8x 4x, which would be a nice shape but collision checks would be insanely difficult. Thats why switching from a 8x8 pixel resolution per index to a 4x4 would be smarter.  
fuuuck me that was sooooo painful, took me several hours to debug all of the quirks and learn all of things I didnt fully understand. okay lovely, we now have a thousand times more complexer logic and storage mechanism and i will have a way harder time to actually go forward, but hey we can have the funny shapes...
%endif
; REMINDER: when we use 0-x dont forget the 0 as a value as well, no more off-by-1 bugs!!
;variables
tetris_grid: times 760 db 0  ; 20 columns x 38 rows - big upgrade baybay 

current_x_index	   dd 10		; signed integer to track from the middle index 10
current_y_index	   dd 0		; signed integer to track the y index (38
current_piece_y    dd 0
current_piece_x    dd 0
last_drawn_x       dd 160
last_drawn_y	   dd 22
score			   dd 0
speed			   dd 6
color dd 0
next_shape_type db SHAPE_CUBE    ; What piece will spawn next

collision_found db 0
