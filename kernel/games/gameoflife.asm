; GENERATED ENTIRELY by AI, i did NOT bother to create GoF because it just didnt interest me lol. I just needed to fill the game amount, and a way to stress test PCs with a 0 delay program
; Game of Life - x86 Assembly (Mode 13h)
; Double-buffered, toroidal grid

COLUMNS     equ 160
ROWS        equ 100
CELL_SIZE   equ 2
GRID_SIZE   equ COLUMNS * ROWS
glider		db 1

section .data

; Offset pairs for 8 neighbors (row, col)
neighbor_offsets:
    db -1, -1   ; top-left
    db -1,  0   ; top
    db -1,  1   ; top-right
    db  0, -1   ; left
    db  0,  1   ; right
    db  1, -1   ; bottom-left
    db  1,  0   ; bottom
    db  1,  1   ; bottom-right

section .bss

buffer_a:   resb GRID_SIZE
buffer_b:   resb GRID_SIZE
current:    resd 1      ; pointer to current buffer
next:       resd 1      ; pointer to next buffer

section .text

; Initialize buffers and seed a pattern
gameoflife_init:
    ; Set up buffer pointers
    mov dword [current], buffer_a
    mov dword [next], buffer_b
    
    ; Clear both buffers
    mov edi, buffer_a
    xor eax, eax
    mov ecx, GRID_SIZE
    rep stosb
    
    mov edi, buffer_b
    xor eax, eax
    mov ecx, GRID_SIZE
    rep stosb
    mov ecx, 0
	cmp byte [glider], 0
	jne .spawn
; here you can experiment with certain patterns, you can take some inspiration from the wiki 
; https://en.wikipedia.org/wiki/Conway's_Game_of_Life
.glider:
    mov byte [esi + 10*COLUMNS + 11], 1   ; row 10, col 11
    mov byte [esi + 11*COLUMNS + 12], 1   ; row 11, col 12
    mov byte [esi + 12*COLUMNS + 10], 1   ; row 12, col 10
    mov byte [esi + 12*COLUMNS + 11], 1   ; row 12, col 11
    mov byte [esi + 12*COLUMNS + 12], 1   ; row 12, col 12
    ret
; spawns a line, creates some cool patterns, though it eats up the CPU
.spawn:
	inc ecx
	add eax, 1
    mov byte [esi + ROWS + COLUMNS + eax], 1    
    cmp ecx, 120
    jl .spawn
	ret
	
; Main game loop
gameoflife:
    call gameoflife_init
    
.generation_loop:
    ; Process all cells
    xor ebx, ebx                ; row = 0
    
.row_loop:
    cmp ebx, ROWS
    jge .swap_buffers
    xor eax, eax                ; col = 0
    
.col_loop:
    cmp eax, COLUMNS
    jge .next_row
    
    ; Save position
    push eax
    push ebx
    

    call count_neighbors         
    movzx edx, cl              
    
    ; Restore position
    pop ebx
    pop eax
    
 
    mov esi, ebx
    imul esi, COLUMNS
    add esi, eax               
    

    push ebx
    mov ebx, [current]
    movzx edi, byte [ebx + esi] ; edi = current state (0 or 1)
    pop ebx
    

    xor ecx, ecx                
    
    test edi, edi
    jz .check_birth
    
    ; Cell is alive: survives with 2-3 neighbors
    cmp edx, 2
    jl .write_state
    cmp edx, 3
    jg .write_state
    mov ecx, 1                  ; survives
    jmp .write_state
    
.check_birth:
    ; Cell is dead: born with exactly 3 neighbors
    cmp edx, 3
    jne .write_state
    mov ecx, 1                  ; born
    
.write_state:
    push ebx
    mov ebx, [next]
    mov [ebx + esi], cl
    pop ebx
    
    inc eax
    jmp .col_loop
    
.next_row:
    inc ebx
    jmp .row_loop
    
.swap_buffers:
    ; Swap buffer pointers
    mov eax, [current]
    mov ebx, [next]
    mov [current], ebx
    mov [next], eax
    
    ; Render
    call render_generation
    
    ; commented out cause in larger simulations, the delaying factor is literally the cpu
    ; increase eax if you dont want your CPU to melt, but thats optional
    ;mov eax, 1
    ;call wait_frames
    
    jmp .generation_loop


; Count live neighbors for cell at (row=ebx, col=eax)
; Returns: cl = neighbor count
count_neighbors:
    push ebx
    push esi
    push edi
    push ebp
    
    mov esi, eax                ; col
    mov edi, ebx                ; row
    xor ecx, ecx                ; neighbor count
    
    lea ebp, [neighbor_offsets]
    mov ebx, 8                  ; 8 neighbors
    
.neighbor_loop:
    ; Load row offset and calculate neighbor row
    movsx eax, byte [ebp]
    add eax, edi                ; neighbor_row
    
    ; Load col offset and calculate neighbor col  
    movsx edx, byte [ebp + 1]
    add edx, esi                ; neighbor_col
    
    ; Wrap row
    test eax, eax
    jns .row_not_neg
    add eax, ROWS
    jmp .row_wrapped
.row_not_neg:
    cmp eax, ROWS
    jl .row_wrapped
    sub eax, ROWS
.row_wrapped:

    ; Wrap col
    test edx, edx
    jns .col_not_neg
    add edx, COLUMNS
    jmp .col_wrapped
.col_not_neg:
    cmp edx, COLUMNS
    jl .col_wrapped
    sub edx, COLUMNS
.col_wrapped:

    ; Calculate index: row * COLUMNS + col
    imul eax, COLUMNS
    add eax, edx
    
    ; Add cell state to count
    push ebx
    mov ebx, [current]
    add cl, [ebx + eax]
    pop ebx
    
    add ebp, 2                  ; next offset pair
    dec ebx
    jnz .neighbor_loop
    
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret


; Render current buffer to screen
render_generation:
	cmp dword [game_running], 1
	je .paused
    push eax
    push ebx
    push ecx
    push edx
    push esi
    
    xor ebx, ebx                ; row = 0
    
.render_row:
    cmp ebx, ROWS
    jge .render_done
    xor eax, eax                ; col = 0
    
.render_col:
    cmp eax, COLUMNS
    jge .render_next_row
    
    ; Get cell state
    mov edx, ebx
    imul edx, COLUMNS
    add edx, eax
    
    push ebx
    mov ebx, [current]
    movzx esi, byte [ebx + edx] ; cell state
    pop ebx
    
    ; Calculate screen position
    push eax
    push ebx
    
    imul eax, CELL_SIZE         ; x = col * CELL_SIZE
    imul ebx, CELL_SIZE         ; y = row * CELL_SIZE
    

    test esi, esi
    jz .color_dead
    mov esi, 15                
    jmp .draw
.paused:
	call g_paused
.color_dead:
    xor esi, esi               
    
.draw:
    mov ecx, CELL_SIZE       
    mov edx, CELL_SIZE          
    call mode13_fill_rect      
    
    pop ebx
    pop eax
    
    inc eax
    jmp .render_col
    
.render_next_row:
    inc ebx
    jmp .render_row
    
.render_done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
