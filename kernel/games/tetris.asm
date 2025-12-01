; ============================================================================
; GenOS Tetris - Clean Rewrite
; ============================================================================
; Grid: 20 columns x 40 rows (standard Tetris dimensions)
; Each cell is 4x4 pixels
; Playfield starts at pixel (120, 20)
; ============================================================================

; Constants
GRID_COLS       equ 20
GRID_ROWS       equ 40
CELL_SIZE1       equ 4
PLAYFIELD_X     equ 120
PLAYFIELD_Y     equ 20

; ============================================================================
; Main Game Entry Point
; ============================================================================
tetris_setup:
    ; Clear screen
    mov al, 0
    call mode13_clear_screen
    
    call tetris_init
    
    call draw_tetris_hud
    call spawn_piece
    
    ; Main game loop
    jmp tetris_loop

; ============================================================================
; init game state
; ============================================================================
tetris_init:
    pushad
    
    ; Clear the grid
    mov edi, tetris_grid
    mov ecx, GRID_COLS * GRID_ROWS
    xor al, al
    rep stosb
    
    ; Reset score and speed
    mov dword [tet_score], 0
    mov dword [tet_drop_speed], 6
    
    ; Initialize piece state
    mov byte [tet_current_type], 0
    mov byte [tet_current_rot], 0
    mov byte [tet_next_type], 1
    
    popad
    ret

; ============================================================================
; main loop
; ============================================================================
tetris_loop:
    ; Check pause 
    cmp byte [game_running], 0
    je .paused
    
    ; Wait for drop interval
    mov eax, [tet_drop_speed]
    call wait_frames
    
    ; Erase current piece
    call erase_piece
    
    ; Try to move piece down
    call try_move_down
    cmp eax, 0
    je .piece_locked
    
    ; Draw piece at new position
    call draw_piece
    
    ; Update HUD
    call update_tetris_hud
    
    jmp tetris_loop

.piece_locked:
    ; draw piece at final position
    call draw_piece
    
    ; lock piece into grid
    call lock_piece
    
    ; Check and clear complete lines
    call check_lines
    
    ; Spawn next piece
    call spawn_piece
    
    ; Check game over (collision at spawn)
    call check_piece_collision
    cmp eax, 1
    je .game_over
    
    jmp tetris_loop

.paused:
    call g_paused
    jmp tetris_loop

.game_over:
    mov esi, gameover_str
    mov eax, 125
    mov ebx, 90
    mov dl, 4
    call mode13_print_string
    
.game_over_wait:
    hlt
    jmp .game_over_wait

; ============================================================================
; Spawn a New Piece
; ============================================================================
spawn_piece:
    pushad
    
    ; current becomes next
    mov al, [tet_next_type]
    mov [tet_current_type], al
    
    ; Reset rotation
    mov byte [tet_current_rot], 0
    
    ; starting position (centered at top)
    mov dword [tet_piece_x], 3
    mov dword [tet_piece_y], 0
    
    ; "random" piece
    call random_piece_type
    mov [tet_next_type], al
    
    popad
    ret

; ============================================================================
; Try Move Down - Returns EAX=1 if moved, EAX=0 if blocked
; ============================================================================
try_move_down:
    push ebx
    push ecx
    push edx
    
    ; Test new position
    mov eax, [tet_piece_x]
    mov ebx, [tet_piece_y]
    inc ebx                     
    
    call test_piece_position
    cmp eax, 0
    je .blocked
    
    inc dword [tet_piece_y] 	; Move successful
    mov eax, 1
    jmp .done

.blocked:
    xor eax, eax

.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================================================
; try left 
; ============================================================================
tetris_move_left:
    pushad
    
    call erase_piece
    
    mov eax, [tet_piece_x]
    dec eax
    mov ebx, [tet_piece_y]
    
    call test_piece_position
    cmp eax, 0
    je .no_move
    
    dec dword [tet_piece_x]

.no_move:
    call draw_piece
    popad
    ret

; ============================================================================
; try right
; ============================================================================
tetris_move_right:
    pushad
    
    call erase_piece
    
    mov eax, [tet_piece_x]
    inc eax
    mov ebx, [tet_piece_y]
    
    call test_piece_position
    cmp eax, 0
    je .no_move
    
    inc dword [tet_piece_x]

.no_move:
    call draw_piece
    popad
    ret

; ============================================================================
; try rotate
; ============================================================================
tetris_rotate:
    pushad
    
    call erase_piece
    
    ; Save current rotation
    mov al, [tet_current_rot]
    push eax
    
    ; Try next rotation
    inc byte [tet_current_rot]
    and byte [tet_current_rot], 3   ; mod 4
    
    mov eax, [tet_piece_x]
    mov ebx, [tet_piece_y]
    call test_piece_position
    cmp eax, 0
    jne .rotate_ok
    
    ; Rotation failed, restore
    pop eax
    mov [tet_current_rot], al
    jmp .done

.rotate_ok:
    add esp, 4                      ; Discard saved rotation

.done:
    call draw_piece
    popad
    ret

; ============================================================================
; fast fall
; ============================================================================
tetris_soft_drop_start:
    mov dword [tet_drop_speed], 2
    ret

tetris_soft_drop_stop:
    mov dword [tet_drop_speed], 6
    ret

; ============================================================================
; Test Piece Position
; Input: EAX = test_x, EBX = test_y
; Output: EAX = 1 if valid, 0 if collision
; ============================================================================
test_piece_position:
    pushad
    
    mov [tet_test_x], eax
    mov [tet_test_y], ebx
    
    ; Get shape bitmask
    call get_shape_ptr              ; ESI = shape data
    
    ; Check each cell of the 4x4 bitmask
    xor ecx, ecx                    ; row = 0
    
.row_loop:
    cmp ecx, 4
    jge .valid
    
    xor edx, edx                    ; col = 0
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if this cell is occupied in the shape
    mov edi, ecx
    shl edi, 2
    add edi, edx
    cmp byte [esi + edi], 0
    je .next_col                    ; Empty cell, skip
    
    ; Calculate grid position
    mov eax, [tet_test_x]
    add eax, edx                    ; grid_x = test_x + col
    mov ebx, [tet_test_y]
    add ebx, ecx                    ; grid_y = test_y + row
    
    ; Check bounds
    cmp eax, 0
    jl .collision                   ; Left wall
    cmp eax, GRID_COLS
    jge .collision                  ; Right wall
    cmp ebx, GRID_ROWS
    jge .collision                  ; Floor
    
    cmp ebx, 0
    jl .next_col
    
    ; Check grid collision
    push ecx
    push edx
    imul ebx, GRID_COLS
    add ebx, eax
    cmp byte [tetris_grid + ebx], 0
    pop edx
    pop ecx
    jne .collision
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop

.valid:
    popad
    mov eax, 1
    ret

.collision:
    popad
    xor eax, eax
    ret

; ============================================================================
; Check Collision at Current Position
; Output: EAX = 1 if collision, 0 if clear
; ============================================================================
check_piece_collision:
    push ebx
    mov eax, [tet_piece_x]
    mov ebx, [tet_piece_y]
    call test_piece_position
    xor eax, 1                      ; Invert: valid->0, collision->1
    pop ebx
    ret

lock_piece:
    pushad
    
    call get_shape_ptr              ; ESI = shape data
    
    xor ecx, ecx                    ; row
    
.row_loop:
    cmp ecx, 4
    jge .done
    
    xor edx, edx                    ; col
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if cell occupied
    mov edi, ecx
    shl edi, 2
    add edi, edx
    cmp byte [esi + edi], 0
    je .next_col
    
    ; Calculate grid position
    mov eax, [tet_piece_x]
    add eax, edx
    mov ebx, [tet_piece_y]
    add ebx, ecx
    
    ; Skip if above visible area
    cmp ebx, 0
    jl .next_col
    
    ; Store in grid
    push ecx
    imul ebx, GRID_COLS
    add ebx, eax
    mov byte [tetris_grid + ebx], 1
    pop ecx
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop
    
.done:
    popad
    ret

check_lines:
    pushad
    
    mov ebx, GRID_ROWS - 1          ; Start from bottom row

.check_row:
    cmp ebx, 0
    jl .done
    
    ; Check if row is complete
    mov eax, ebx
    imul eax, GRID_COLS
    lea edi, [tetris_grid + eax]
    mov ecx, GRID_COLS
    
.check_cell:
    cmp byte [edi], 0
    je .not_complete
    inc edi
    dec ecx
    jnz .check_cell
    
    ; Row is complete - clear it
    push ebx
    call clear_line                 ; EBX = row to clear
    pop ebx
    
    ; Increment score
    add dword [tet_score], 100
    
    ; Don't decrement - check same row again (rows shifted down)
    jmp .check_row
    
.not_complete:
    dec ebx
    jmp .check_row
    
.done:
    popad
    ret

; ============================================================================
; Clear Line and Drop Above
; Input: EBX = row index to clear
; ============================================================================
clear_line:
    pushad
    
    ; Flash the line
    mov eax, PLAYFIELD_X
    push ebx
    imul ebx, CELL_SIZE1
    add ebx, PLAYFIELD_Y
    mov ecx, GRID_COLS * CELL_SIZE1
    mov edx, CELL_SIZE1
    mov esi, 15                     ; White flash
    call mode13_fill_rect
    pop ebx
    
    ; Small delay for visual effect
    mov eax, 3
    call wait_frames
    
    ; Shift all rows above down by one
    mov esi, ebx                    ; Current row (destination)
    
.shift_loop:
    cmp esi, 0
    jle .clear_top
    
    ; Copy row above (esi-1) to current row (esi)
    mov eax, esi
    dec eax
    imul eax, GRID_COLS
    lea edi, [tetris_grid + eax]    ; Source: row above
    
    mov eax, esi
    imul eax, GRID_COLS
    lea ebx, [tetris_grid + eax]    ; Dest: current row
    
    mov ecx, GRID_COLS
.copy_cell:
    mov al, [edi]
    mov [ebx], al
    inc edi
    inc ebx
    dec ecx
    jnz .copy_cell
    
    dec esi
    jmp .shift_loop
    
.clear_top:
    ; Clear top row
    lea edi, [tetris_grid]
    mov ecx, GRID_COLS
    xor al, al
    rep stosb
    
    ; Redraw entire playfield
    call redraw_playfield
    
    popad
    ret

; ============================================================================
; redraw playfield
; ============================================================================
redraw_playfield:
    pushad
    
    ; Clear playfield area
    mov eax, PLAYFIELD_X
    mov ebx, PLAYFIELD_Y
    mov ecx, GRID_COLS * CELL_SIZE1
    mov edx, GRID_ROWS * CELL_SIZE1
    mov esi, 0
    call mode13_fill_rect
    
    ; Draw all locked cells
    xor ebx, ebx                    ; row
    
.row_loop:
    cmp ebx, GRID_ROWS
    jge .done
    
    xor eax, eax                    ; col
    
.col_loop:
    cmp eax, GRID_COLS
    jge .next_row
    
    ; Check grid cell
    push eax
    push ebx
    mov ecx, ebx
    imul ecx, GRID_COLS
    add ecx, eax
    cmp byte [tetris_grid + ecx], 0
    pop ebx
    pop eax
    je .skip_cell
    
    ; Draw this cell
    push eax
    push ebx
    
    ; Calculate pixel position
    imul eax, CELL_SIZE1
    add eax, PLAYFIELD_X
    imul ebx, CELL_SIZE1
    add ebx, PLAYFIELD_Y
    
    ; Draw filled cell
    mov ecx, CELL_SIZE1 - 1
    mov edx, CELL_SIZE1 - 1
    mov esi, 8                      ; Dark gray for locked pieces
    call mode13_fill_rect
    
    pop ebx
    pop eax
    
.skip_cell:
    inc eax
    jmp .col_loop
    
.next_row:
    inc ebx
    jmp .row_loop
    
.done:
    popad
    ret

; ============================================================================
; draw piece
; ============================================================================
draw_piece:
    pushad
    
    call get_shape_ptr              ; ESI = shape data
    movzx edi, byte [tet_current_type]
    mov edi, [piece_colors + edi*4] ; Get piece color
    
    xor ecx, ecx                    ; row
    
.row_loop:
    cmp ecx, 4
    jge .done
    
    xor edx, edx                    ; col
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if cell occupied
    mov eax, ecx
    shl eax, 2
    add eax, edx
    cmp byte [esi + eax], 0
    je .next_col
    
    ; Calculate pixel position
    mov eax, [tet_piece_x]
    add eax, edx
    imul eax, CELL_SIZE1
    add eax, PLAYFIELD_X
    
    mov ebx, [tet_piece_y]
    add ebx, ecx
    
    ; Skip if above visible area
    cmp ebx, 0
    jl .next_col
    
    imul ebx, CELL_SIZE1
    add ebx, PLAYFIELD_Y
    
    ; Draw cell
    push ecx
    push edx
    push esi
    mov ecx, CELL_SIZE1 - 1
    mov edx, CELL_SIZE1 - 1
    mov esi, edi                    ; Color
    call mode13_fill_rect
    pop esi
    pop edx
    pop ecx
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop
    
.done:
    popad
    ret

; ============================================================================
; erase piece
; ============================================================================
erase_piece:
    pushad
    
    call get_shape_ptr              ; ESI = shape data
    
    xor ecx, ecx                    ; row
    
.row_loop:
    cmp ecx, 4
    jge .done
    
    xor edx, edx                    ; col
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if cell occupied
    mov eax, ecx
    shl eax, 2
    add eax, edx
    cmp byte [esi + eax], 0
    je .next_col
    
    ; Calculate pixel position
    mov eax, [tet_piece_x]
    add eax, edx
    imul eax, CELL_SIZE1
    add eax, PLAYFIELD_X
    
    mov ebx, [tet_piece_y]
    add ebx, ecx
    
    ; Skip if above visible area
    cmp ebx, 0
    jl .next_col
    
    imul ebx, CELL_SIZE1
    add ebx, PLAYFIELD_Y
    
    ; Erase cell (black)
    push ecx
    push edx
    push esi
    mov ecx, CELL_SIZE1 - 1
    mov edx, CELL_SIZE1 - 1
    mov esi, 0
    call mode13_fill_rect
    pop esi
    pop edx
    pop ecx
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop
    
.done:
    popad
    ret

; ============================================================================
; Get Shape Pointer
; Output: ESI = pointer to 4x4 shape data for current piece/rotation
; ============================================================================
get_shape_ptr:
    push eax
    push ebx
    
    ; Calculate: shape_table + (type * 4 + rotation) * 16
    movzx eax, byte [tet_current_type]
    shl eax, 2                      ; type * 4
    movzx ebx, byte [tet_current_rot]
    add eax, ebx                    ; + rotation
    shl eax, 4                      ; * 16 bytes per shape
    lea esi, [tet_shapes + eax]
    
    pop ebx
    pop eax
    ret

; ============================================================================
; draw HUD
; ============================================================================
draw_tetris_hud:
    pushad
    
    ; Border around playfield
    ; Left border
    mov eax, PLAYFIELD_X - 3
    mov ebx, PLAYFIELD_Y - 3
    mov ecx, 3
    mov edx, GRID_ROWS * CELL_SIZE1 + 6
    mov esi, 15
    call mode13_fill_rect
    
    ; Right border
    mov eax, PLAYFIELD_X + GRID_COLS * CELL_SIZE1
    mov ebx, PLAYFIELD_Y - 3
    mov ecx, 3
    mov edx, GRID_ROWS * CELL_SIZE1 + 6
    mov esi, 15
    call mode13_fill_rect
    
    ; Top border
    mov eax, PLAYFIELD_X - 3
    mov ebx, PLAYFIELD_Y - 3
    mov ecx, GRID_COLS * CELL_SIZE1 + 6
    mov edx, 3
    mov esi, 15
    call mode13_fill_rect
    
    ; Bottom border
    mov eax, PLAYFIELD_X - 3
    mov ebx, PLAYFIELD_Y + GRID_ROWS * CELL_SIZE1
    mov ecx, GRID_COLS * CELL_SIZE1 + 6
    mov edx, 3
    mov esi, 15
    call mode13_fill_rect
    
    ; Score label
    mov esi, score_label
    mov eax, 10
    mov ebx, 30
    mov dl, 15
    call mode13_print_string
    
    ; Next label
    mov esi, next_label
    mov eax, 230
    mov ebx, 30
    mov dl, 15
    call mode13_print_string
    
    
    popad
    
    ret
;============================================================================
; draw next piece
; ============================================================================
draw_next_piece:
    pushad
    
    ; Get shape pointer for next piece 
    movzx eax, byte [tet_next_type]
    shl eax, 6                      ; type * 64 (4 rotations * 16 bytes)
    lea esi, [tet_shapes + eax]     ; rotation 0 of next piece
    
    ; Get color for next piece
    movzx edi, byte [tet_next_type]
    mov edi, [piece_colors + edi*4]
    
    xor ecx, ecx                    ; row
    
.row_loop:
    cmp ecx, 4
    jge .done
    
    xor edx, edx                    ; col
    
.col_loop:
    cmp edx, 4
    jge .next_row
    
    ; Check if cell occupied in bitmask
    mov eax, ecx
    shl eax, 2
    add eax, edx
    cmp byte [esi + eax], 0
    je .next_col
    
    ; Calculate pixel position for preview box
    push ecx
    push edx
    push esi
    
    mov eax, edx                    ; col
    imul eax, CELL_SIZE
    add eax, 240                    ; preview X position
    
    mov ebx, ecx                    ; row  
    imul ebx, CELL_SIZE
    add ebx, 45                     ; preview Y position
    
    mov ecx, 4
    mov edx, 4	
    mov esi, edi                    ; Color
    call mode13_fill_rect
    
    pop esi
    pop edx
    pop ecx
    
.next_col:
    inc edx
    jmp .col_loop
    
.next_row:
    inc ecx
    jmp .row_loop
    
.done:
    popad
    ret
; ============================================================================
; Update HUD 
; ============================================================================
update_tetris_hud:
    pushad
    
    ; Clear score area
    mov eax, 10
    mov ebx, 42
    mov ecx, 48
    mov edx, 10
    mov esi, 0
    call mode13_fill_rect
    
    ; Draw score value
    mov eax, [tet_score]
    call int_to_string
    mov esi, [int_result]
    mov eax, 10
    mov ebx, 42
    mov dl, 15
    call mode13_print_string
    ; Clear previous next piece
    mov eax, 239 
    mov ebx, 39
    mov ecx, 32
    mov edx, 32
    mov esi, 0
    call mode13_fill_rect

 	call draw_next_piece
    popad
    ret
; 32-bit xorshift PRNG
; Output: EAX = random value, also updates tet_random_seed
xorshift32_tetris:
    mov eax, [tet_random_seed]
    mov ebx, eax
    shl ebx, 13
    xor eax, ebx
    mov ebx, eax
    shr ebx, 17
    xor eax, ebx
    mov ebx, eax
    shl ebx, 5
    xor eax, ebx
    mov [tet_random_seed], eax
    ret

; Get random piece type (0-6)
random_piece_type:
    call xorshift32_tetris
    xor edx, edx
    mov ecx, 7
    div ecx                         ; EDX = EAX mod 7
    mov eax, edx
    ret



; ============================================================================
; Shape Data - All 7 Tetrominos with 4 rotations each
; Each shape is 4x4 bytes (16 bytes per rotation, 64 bytes per piece)
; ============================================================================

tet_shapes:
; I-piece (index 0)
    db 0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0  ; rotation 0
    db 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0  ; rotation 1
    db 0,0,0,0, 0,0,0,0, 1,1,1,1, 0,0,0,0  ; rotation 2
    db 0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0  ; rotation 3

; O-piece (index 1)
    db 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0  ; all rotations same
    db 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
    db 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
    db 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0

; T-piece (index 2)
    db 0,1,0,0, 1,1,1,0, 0,0,0,0, 0,0,0,0  ; rotation 0
    db 0,1,0,0, 0,1,1,0, 0,1,0,0, 0,0,0,0  ; rotation 1
    db 0,0,0,0, 1,1,1,0, 0,1,0,0, 0,0,0,0  ; rotation 2
    db 0,1,0,0, 1,1,0,0, 0,1,0,0, 0,0,0,0  ; rotation 3

; S-piece (index 3)
    db 0,1,1,0, 1,1,0,0, 0,0,0,0, 0,0,0,0  ; rotation 0
    db 0,1,0,0, 0,1,1,0, 0,0,1,0, 0,0,0,0  ; rotation 1
    db 0,0,0,0, 0,1,1,0, 1,1,0,0, 0,0,0,0  ; rotation 2
    db 1,0,0,0, 1,1,0,0, 0,1,0,0, 0,0,0,0  ; rotation 3

; Z-piece (index 4)
    db 1,1,0,0, 0,1,1,0, 0,0,0,0, 0,0,0,0  ; rotation 0
    db 0,0,1,0, 0,1,1,0, 0,1,0,0, 0,0,0,0  ; rotation 1
    db 0,0,0,0, 1,1,0,0, 0,1,1,0, 0,0,0,0  ; rotation 2
    db 0,1,0,0, 1,1,0,0, 1,0,0,0, 0,0,0,0  ; rotation 3

; J-piece (index 5)
    db 1,0,0,0, 1,1,1,0, 0,0,0,0, 0,0,0,0  ; rotation 0
    db 0,1,1,0, 0,1,0,0, 0,1,0,0, 0,0,0,0  ; rotation 1
    db 0,0,0,0, 1,1,1,0, 0,0,1,0, 0,0,0,0  ; rotation 2
    db 0,1,0,0, 0,1,0,0, 1,1,0,0, 0,0,0,0  ; rotation 3

; L-piece (index 6)
    db 0,0,1,0, 1,1,1,0, 0,0,0,0, 0,0,0,0  ; rotation 0
    db 0,1,0,0, 0,1,0,0, 0,1,1,0, 0,0,0,0  ; rotation 1
    db 0,0,0,0, 1,1,1,0, 1,0,0,0, 0,0,0,0  ; rotation 2
    db 1,1,0,0, 0,1,0,0, 0,1,0,0, 0,0,0,0  ; rotation 3

; ============================================================================
; Piece Colors (VGA palette indices)
; ============================================================================
piece_colors:
    dd 11       ; I - cyan
    dd 14       ; O - yellow
    dd 5        ; T - purple
    dd 10       ; S - green
    dd 4        ; Z - red
    dd 1        ; J - blue
    dd 6        ; L - orange

; ============================================================================
; Variables
; ============================================================================
tetris_grid:        times GRID_COLS * GRID_ROWS db 0

tet_piece_x:        dd 3            ; Current piece grid X
tet_piece_y:        dd 0            ; Current piece grid Y
tet_current_type:   db 0            ; Current piece type (0-6)
tet_current_rot:    db 0            ; Current rotation (0-3)
tet_next_type:      db 1            ; Next piece type
tet_score:          dd 0
tet_drop_speed:     dd 6            ; Frames between drops

tet_test_x:         dd 0            ; Temp for collision testing
tet_test_y:         dd 0

; Strings
score_label:        db 'SCORE', 0
next_label:         db 'NEXT', 0
pause_str:          db 'PAUSED', 0
gameover_str:       db 'GAME OVER', 0
tet_random_seed: dd 60332681
%if 0
uncertain how I should design the score system, maybe 1 per line? but it feels like blocks come every bluemoon due to it being slow as shit, imma add the gravity accel via S
okay so after adding this whole mumbo jumbo, I think its time to switch to heavier guns, time for complexer shapes
but lets say we create the L piece, its normally start 0/0 4x 16y and start 4/12 8x 4x, which would be a nice shape but collision checks would be insanely difficult. Thats why switching from a 8x8 pixel resolution per index to a 4x4 would be smarter.  
fuuuck me that was sooooo painful, took me several hours to debug all of the quirks and learn all of things I didnt fully understand. okay lovely, we now have a thousand times more complexer logic and storage mechanism and i will have a way harder time to actually go forward, but hey we can have the funny shapes...
so I guess it was rather a larger pain in the ass to keep as is than to just completely rewrite it but with writen down logic of how it should be.
REMINDER:
use global variables at all times, do not hardcode unless it is necessary
go through each frame+n and the logic behind it until you find the issue
%endif
