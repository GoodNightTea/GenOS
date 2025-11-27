; most advanced snake simulator in existence
[BITS 32]
[ORG 0x100000]
kernel_entry:
    mov esp, 0x7C00
    cli
    
    call setup_idt
    call setup_timer_idt
    call init_pics
    call init_timer
    sti
    mov al, 0
    call mode13_clear_screen
    
    mov esi, menu
    mov eax, 130
    mov ebx, 80
    mov dl, 100
    call mode13_print_string
    
    mov byte [menu_choice], 0

.wait_for_choice:
    hlt                              ; Wait for keyboard interrupt
    mov al, [menu_choice]            ; Check what user pressed
    cmp al, 1
    je .snake
    cmp al, 2
    je .tetris
    cmp al, 3
    je .test
    cmp al, 4
    je .gof
    jmp .wait_for_choice             ; Keep waiting if 0

.gof:
	call gameoflife
	jmp .gof
.test:
	call test
	jmp .test	
.snake:
    mov al, 0
    call mode13_clear_screen
    mov esi, snake
    mov eax, 130
    mov ebx, 5
    mov dl, 100
    call mode13_print_string
	jmp .snake_continue   
.tetris:
    call tetris_setup
    
.snake_continue:
    ; Setup palette colors
    call setup_snake_palette
    
    ; Clear screen to black
    call draw_border

    
    ; INITIALIZE SNAKE PROPERLY (grid coords, not pixels)
    mov dword [snake_x + 0], 17
    mov dword [snake_x + 4], 18
    mov dword [snake_x + 8], 19
    mov dword [snake_x + 12], 20
    
    mov dword [snake_y + 0], 12
    mov dword [snake_y + 4], 12
    mov dword [snake_y + 8], 12
    mov dword [snake_y + 12], 12
    
    mov dword [snake_head], 3
    mov dword [snake_tail], 0
    
    ; Draw initial snake
    mov ecx, 0
.draw_initial:
    cmp ecx, 4
    jge .game
    
    push ecx
    shl ecx, 2
    mov eax, [snake_x + ecx]
    mov ebx, [snake_y + ecx]
    pushad
    call draw_snake_segment
    popad
    pop ecx
    inc ecx
    jmp .draw_initial

.game:
    ; Check if game is still running
    cmp byte [game_running], 0
    je .paused


 	cmp dword [apple_count], 10  
    jge .continue_game           ; Changed to JGE (greater or equal)
    call spawn_single_apple      ; Only spawn if < 10

.continue_game:
	mov eax, [snake_len]
	call display_number
    
    ; Calculate new head position
    mov eax, [snake_head]
    mov ebx, eax
    shl ebx, 2
    
    ; Get current head position
    mov ecx, [snake_x + ebx]
    mov edx, [snake_y + ebx]
    
    ; Get direction delta
    push ecx
    push edx
    call get_direction_delta
    pop edx
    pop ecx
    
    ; Apply movement
    add ecx, eax
    add edx, ebx
    
    ; Wrap around edges (X axis) - 40 columns
    cmp ecx, 3
    jge .check_x_max
    mov ecx, 36
    jmp .check_y
    
.paused:
    mov esi, paused          ; Point to string
	mov eax, 130                 ; X position
	mov ebx, 80                 ; Y position
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




.check_x_max:
    cmp ecx, 37
    jl .check_y
    mov ecx, 3
    
.check_y:
    ; Wrap around edges (Y axis) - 25 rows
    cmp edx, 3
    jge .check_y_max
    mov edx, 21
    jmp .no_wrap
    
.check_y_max:
    cmp edx, 22
    jl .no_wrap
    mov edx, 3
    
.no_wrap:
    ; Advance head
    inc dword [snake_head]
    mov eax, [snake_head]
    cmp eax, max_length
    jl .no_wrap_head
    mov dword [snake_head], 0
    
.no_wrap_head:
    ; Store new head position
    mov eax, [snake_head]
    shl eax, 2
    mov [snake_x + eax], ecx
    mov [snake_y + eax], edx
    
    ; CHECK COLLISION
    call check_apple_collision
    cmp eax, 0
    je .skip_tail_erase
    
.erase_tail:
    ; Normal movement - erase tail
    mov eax, [snake_tail]
    shl eax, 2
    mov ebx, [snake_x + eax]
    mov ecx, [snake_y + eax]
    pushad
    mov eax, ebx
    mov ebx, ecx
    call erase_cell
    popad
    
    ; Advance tail index
    inc dword [snake_tail]
    mov eax, [snake_tail]
    cmp eax, max_length
    jl .skip_tail_erase
    mov dword [snake_tail], 0
    
.skip_tail_erase:
    ; Draw new head
    mov eax, [snake_head]
    shl eax, 2
    mov ebx, [snake_x + eax]
    mov ecx, [snake_y + eax]
    pushad
    mov eax, ebx
    mov ebx, ecx
    call draw_snake_segment
    popad
    
    
    mov eax, 3
    call wait_frames
    jmp .game
    
check_apple_collision:
    mov [temp_head_x], ecx
    mov [temp_head_y], edx
    xor edi, edi
    
.check_loop:
    cmp edi, [apple_count]
    jge .no_collision
    
    ; Check X
    mov eax, [food_x + edi*4]
    cmp eax, [temp_head_x]
    jne .next_apple
    
    ; Check Y
    mov eax, [food_y + edi*4]
    cmp eax, [temp_head_y]
    jne .next_apple
    
.collision:
    ; Remove this apple by swapping with last apple
    mov eax, [apple_count]
    dec eax                        ; last valid index
    
    cmp edi, eax                   ; If we ate the last apple, just decrement
    je .just_decrement
    
    ; Swap last apple into this position
    mov ebx, [food_x + eax*4]
    mov [food_x + edi*4], ebx
    mov ebx, [food_y + eax*4]
    mov [food_y + edi*4], ebx
    
.just_decrement:
    dec dword [apple_count]
    call spawn_single_apple
    inc dword [snake_len]
    xor eax, eax
    ret
    
.next_apple:
    inc edi
    jmp .check_loop
    
.no_collision:
    mov eax, 1                 ; Return 1 = no collision
    ret
    
; Single unified apple spawner
spawn_single_apple:
    ; Input: nothing
    ; Output: spawns 1 apple in valid position and increments apple_count
    pushad
    cmp dword [apple_count], 10
    je .return
.retry:
    call xorshift32
    push eax
    ; X: 3-32
    movzx eax, ax
    xor edx, edx
    mov ebx, 30
    div ebx
    add edx, 3
    mov [temp_spawn_x], edx
    
    ; Y: 3-24
    pop eax    
    movzx eax, ax
    xor edx, edx
    mov ebx, 16
    div ebx
    add edx, 3
    mov [temp_spawn_y], edx

    ; Check if it spawned on snake body
    mov eax, [temp_spawn_x]
    mov ebx, [temp_spawn_y]
    call check_spawn_collision
    cmp eax, 1
    je .retry  ; Collision, try again
    
    ; Valid position - store it
    mov ecx, [apple_count]
    mov eax, [temp_spawn_x]
    mov [food_x + ecx*4], eax
    mov eax, [temp_spawn_y]
    mov [food_y + ecx*4], eax

	; Draw it
    mov eax, [temp_spawn_x]
    mov ebx, [temp_spawn_y]
    call draw_apple
    
    inc dword [apple_count]
.return:
    popad
    ret




; ============================================================================
; Helper Functions
; ============================================================================
check_spawn_collision:
	push ecx
	push edx
	push edi
	push esi
	
	mov [temp_spawn_x], eax
	mov [temp_spawn_y], ebx
	
	mov ecx, [snake_head]
	mov edx, [snake_tail]
	
	mov esi, edx				; start at tail
.check_segment:
	cmp esi, ecx
	je .after_head
	mov edi, esi
	shl edi, 2
	mov eax, [snake_x + edi]
	mov ebx, [snake_y + edi]
	
	cmp eax, [temp_spawn_x]
	jne .next_segment
	cmp ebx, [temp_spawn_y]
	je .collision_found
.next_segment:
	inc esi
	cmp esi, max_length
	jl .check_segment
	xor esi, esi
	jmp .check_segment
.after_head:
	mov edi, ecx
	shl edi, 2
	mov eax, [snake_x + edi]
	mov ebx, [snake_y + edi]
	cmp eax, [temp_spawn_x]
	jne .no_collision
	cmp ebx, [temp_spawn_y]
	je .collision_found
.no_collision:
	xor eax, eax
	jmp .done
.collision_found:
	mov eax, 1
.done:
	pop esi
	pop edi
	pop edx
	pop ecx
	ret

    
setup_snake_palette:
    pushad
    
    ; Snake body: Bright green
    mov al, 42
    mov bl, 0
    mov bh, 63
    mov cl, 0
    call set_palette_color
    
    ; Apple: Bright red
    mov al, 12
    mov bl, 63
    mov bh, 0
    mov cl, 0
    call set_palette_color
    
    ; White for text/UI
    mov al, 15
    mov bl, 63
    mov bh, 63
    mov cl, 63
    call set_palette_color
    
    popad
    ret

set_palette_color:
    ; Input: AL = index, BL = red, BH = green, CL = blue (0-63)
    push ax
    push dx
    
    mov dx, 0x03C8
    out dx, al
    
    mov dx, 0x03C9
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al
    mov al, cl
    out dx, al
    
    pop dx
    pop ax
    ret

calculate_length:
    mov eax, [snake_head]
    mov ebx, [snake_tail]
    sub eax, ebx
    jge .positive
    add eax, max_length
.positive:
    inc eax
    ret

display_number:
; fill_rect help
; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
    pushad
    mov eax, 0
    mov ebx, 0
    mov ecx, 18
    mov edx, 10
    mov esi, 0x00
    call mode13_fill_rect
	popad
    pushad
    ; Handle numbers 0-99
    cmp eax, 10
    jl .single_digit
    
    ; Two digits - draw tens place
    mov ebx, 10
    xor edx, edx
    div ebx                    ; EAX = tens, EDX = ones
    
    push edx                   ; Save ones digit
    
    add al, '0'
    mov cl, al
    mov eax, 2
    mov ebx, 2
    mov dl, 15
    call draw_char
    
    
    ; Draw ones place
    pop eax                    ; Get ones digit back
    add al, '0'
    mov cl, al
    mov eax, 10                ; X = 10 (next to first digit)
    mov ebx, 2
    mov dl, 15
    call draw_char
    
    popad
    ret
    
.single_digit:
    add al, '0'
    mov cl, al
    mov eax, 2
    mov ebx, 2
    mov dl, 15
    call draw_char
    
    popad
    ret
    
    
; ============================================================================
; Misc LOGIC
; ============================================================================
; collision check time
; idea: basically just store x and y of current head coords and compare to each food x and y 
; jump if hit
; great another collision check, this time for the spawn of an apple
check_collision:
	popad
	
	mov [temp_spawn_x], eax
	mov [temp_spawn_y], ebx
	
	mov ecx, [snake_head]
	mov edx, [snake_tail]
	
	mov esi, edx				; start at tail
.check_segment:
	cmp esi, ecx
	je .after_head
	mov edi, esi
	shl edi, 2
	mov eax, [snake_x + edi]
	mov ebx, [snake_y + edi]
	
	cmp eax, [temp_spawn_x]
	jne .next_segment
	cmp ebx, [temp_spawn_y]
	je .collision_found
.next_segment:
	inc esi
	cmp esi, max_length
	jl .check_segment
	xor esi, esi
	jmp .check_segment
.after_head:
	mov edi, ecx
	shl edi, 2
	mov eax, [snake_x + edi]
	mov ebx, [snake_y + edi]
	cmp eax, [temp_spawn_x]
	jne .no_collision
	cmp ebx, [temp_spawn_y]
	je .collision_found
.no_collision:
	xor eax, eax
	jmp .done
.collision_found:
	mov eax, 1
.done:
	popad
	ret

xorshift32:
    push ebx
    mov eax, [rng_seed]
    mov ebx, eax
    
    shl eax, 13
    xor eax, ebx
    
    mov ebx, eax
    shr eax, 17
    xor eax, ebx
    
    mov ebx, eax
    shl eax, 5
    xor eax, ebx
    mov [rng_seed], eax
    pop ebx
    ret

; ============================================================================
; IDT Setup
; ============================================================================
setup_idt:
    pushad
    
    ; Use a fixed safe location for IDT: 0x110000 (well past kernel)
    mov edi, 0x110000
    
    ; Clear IDT
    push edi
    mov ecx, 512
    xor eax, eax
    rep stosd
    pop edi
    
    ; Setup keyboard interrupt (IRQ1 = INT 33)
    ; Calculate absolute address of handler
    mov eax, 0x100000
    mov ebx, keyboard_handler
    sub ebx, kernel_entry
    add eax, ebx                    ; EAX = absolute handler address
    
    ; Point to IDT entry 33 (IRQ1)
    add edi, (33 * 8)
    
    mov word [edi], ax              ; Low 16 bits of handler
    mov word [edi + 2], 0x08        ; Code segment
    mov byte [edi + 4], 0           ; Reserved
    mov byte [edi + 5], 0x8E        ; Present, ring 0, interrupt gate
    shr eax, 16
    mov word [edi + 6], ax          ; High 16 bits of handler
    
    ; Set IDT descriptor to point to fixed location
    mov dword [idt_desc + 2], 0x110000
    
    ; Load IDT
    lidt [idt_desc]
    
    popad
    ret

keyboard_handler:
    pushad
    
    ; Read scancode from keyboard controller
    in al, 0x60
    
    ; Process the scancode
    call process_scancode
    
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

%if 0
so it seems that with this if 0 statement, I can create a conditional block that never gets evaluated and therefor create a multiline comment in assembly, imma abuse the hell out of that.
; =============================================================================
; Actual issues found
; =============================================================================
apple_race:
	There was a nasty race condition inside of the apple spawn logic and body redraw logic.
	When an apple generates the pseudorandom coordinates for the next spawnpoint, it may overlap with the snakes body
out-of-bounds:
	there was an oob with the apple respawn logic where I forgot that now with the 13h display I had to recalculate the width of where apples are allowed to spawn and they just spawned outside of the border and made them "despawn"

second_apple_race:
	there was ANOTHER apple race where sure I checked if there was a body but I didnt check for the potential of soon-to-be deleted tail, dont ask how, I dont understand it either but it should be gone (hopefully)

direction_based_race:
	theres a check that prevents 180 degree turns and it works, yet if one is able to turn down (or up) and then the opposite direction, one can make a 180 degree turn in one frame. Have still yet to figure out an efficient method to patch this without fucking up the fps
	
%endif
; ============================================================================
; Include Drivers
; ============================================================================

%include "fonts/font1.asm"
%include "vga/13h_vga.asm"
%include "keyboard/keyboard_driver.asm"
%include "timer/timer_driver.asm"
%include "kernel/tetris.asm"
%include "kernel/test.asm"
%include "kernel/gameoflife.asm"
; ============================================================================
; Data Section
; ============================================================================

; Variables
length_buffer times 11 db 0    ; "4294967295\0" worst case for 32-bit

max_length    equ 100
temp_head_y   dd 0
temp_head_x   dd 0
snake_x       times 100 dd 0
snake_y       times 100 dd 0
food_x        times 10 dd 0      ; Array for multiple apples
food_y        times 10 dd 0      ; Array for multiple apples
snake_head    dd 3
snake_tail    dd 0
snake_len     dd 4

rng_seed      dd 88172645        ; seed for "random" coord generation
apple_count   dd 0               ; Changed to dword for consistency

temp_spawn_x  dd 0 		
temp_spawn_y  dd 0		 
paused 	      db 'PAUSED', 0
menu		  db 'SNAKE OR TETRIS', 0
snake		  db 'SNAKE', 0


; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)
