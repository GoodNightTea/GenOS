; most advanced snake simulator in existence
[BITS 32]
[ORG 0x100000]
kernel_entry:
    mov esp, 0x7C00
    cli
    
    call setup_idt
    call setup_timer_idt        ; setup timer interrupt
    call init_pics
    call init_timer             ; init PIT
    sti
    
    ; Clear screen
    mov eax, 0x00
    call vga_clear_screen
    
    ; INITIALIZE SNAKE PROPERLY
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
    mov ecx, '#'
    mov edx, 0x2A
    call vga_write_char_at
    popad
    pop ecx
    inc ecx
    jmp .draw_initial

.game:
    ; Check if game is still running
    cmp byte [game_running], 0
    je .paused
    
    ; Check if we need to spawn apples, use dword bru
    cmp dword [apple_count], 10
    jl .spawn_apple              ; Jump if less than 5
    
    
.continue_game:
	; calculate current length of snake
	call calculate_length
	; convert and display the current number
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
    call get_direction_delta        ; Returns EAX=delta_x, EBX=delta_y
    pop edx
    pop ecx
    
    ; Apply movement
    add ecx, eax                    ; new_x = old_x + delta_x
    add edx, ebx                    ; new_y = old_y + delta_y
    
    ; Wrap around edges (X axis)
    cmp ecx, 0
    jge .check_x_max
    mov ecx, 79                     ; Wrap to right edge
    jmp .check_y
    
.check_x_max:
    cmp ecx, 80
    jl .check_y
    mov ecx, 0                      ; Wrap to left edge
    
.check_y:
    ; Wrap around edges (Y axis)
    cmp edx, 0
    jge .check_y_max
    mov edx, 24                     ; Wrap to bottom
    jmp .no_wrap
    
.check_y_max:
    cmp edx, 25
    jl .no_wrap
    mov edx, 0                      ; Wrap to top
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
    
    ; CHECK COLLISION (ECX=new_x, EDX=new_y)
    call check_apple_collision  ; Returns EAX: 0=collision, 1=no collision
    cmp eax, 0
    je .skip_tail_erase         ; If collision, skip tail erase
    
.erase_tail:
    ; Normal movement - erase tail
    mov eax, [snake_tail]
    shl eax, 2
    mov ebx, [snake_x + eax]
    mov ecx, [snake_y + eax]
    pushad
    mov eax, ebx
    mov ebx, ecx
    mov ecx, ' '
    mov edx, 0x00
    call vga_write_char_at
    popad
    
    ; Advance tail index
    inc dword [snake_tail]
    mov eax, [snake_tail]
    cmp eax, max_length
    jl .skip_tail_erase
    mov dword [snake_tail], 0
    
; note: this advances the snake by skipping 
.skip_tail_erase:               
    ; Draw new head 
    mov eax, [snake_head]
    shl eax, 2
    mov ebx, [snake_x + eax]
    mov ecx, [snake_y + eax]
    pushad
    mov eax, ebx
    mov ebx, ecx
    mov ecx, '#'
    mov edx, 0x2A
    call vga_write_char_at
    popad
    
    ; Timer delay
    movzx eax, byte [current_direction]
    cmp eax, DIR_UP
    je .vertical_delay
    cmp eax, DIR_DOWN
    je .vertical_delay
    
    mov eax, 3
    call wait_frames
    jmp .game
    
.vertical_delay:
    mov eax, 5
    call wait_frames
    jmp .game

.paused:
    ; Print pause
    mov eax, 30
    mov ebx, 12
    mov ecx, paused
    mov edx, 0x0C                   ; Bright red
    call vga_print_string_at
	cmp byte [game_running], 0
	je .paused
	jmp .game
 
.spawn_apple:
    call xorshift32
    push eax
    mov ecx, [apple_count]
    
    ; Use lower 16 bits for X
    movzx eax, ax
    xor edx, edx
    mov ebx, 80
    div ebx
    mov [food_x + ecx*4], edx       ; Store in array indexed by apple_count
    
    ; Use upper 16 bits for Y
    pop eax
    shr eax, 16
    xor edx, edx
    mov ebx, 25
    div ebx
    mov ecx, [apple_count]          ; Get current apple index
    mov [food_y + ecx*4], edx       ; Store in array
    
    ; Draw apple
    mov eax, [food_x + ecx*4]
    mov ebx, [food_y + ecx*4]
    push ecx
    mov ecx, 'O'
    mov edx, 0x0C
    call vga_write_char_at
    pop ecx
    
    inc dword [apple_count]         ; dword again bru stop confusing them
    jmp .continue_game

; ============================================================================
; Helper Functions
; ============================================================================
; To get current length:
calculate_length:
    mov eax, [snake_head]
    mov ebx, [snake_tail]
    sub eax, ebx
    jge .positive
    add eax, max_length    ; Handle wraparound
.positive:
    inc eax                ; +1 because both head and tail are inclusive
    ret

; Helper: Convert EAX to string, write at (display_x, display_y)
; Preserves all registers
display_number:
    pushad
    
    ; Convert to string in buffer
    mov edi, length_buffer
    mov ebx, 10
    mov ecx, 0
    
    ; Handle zero
    test eax, eax
    jnz .convert
    mov byte [edi], '0'
    mov byte [edi+1], 0
    jmp .display
    
.convert:
    ; Build string backwards in temp buffer
    lea edi, [length_buffer + 9]  ; Start at end
    mov byte [edi], 0              ; Null terminator
    dec edi
    
.push_digits:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    dec edi
    test eax, eax
    jnz .push_digits
    
    ; EDI now points to first digit
    inc edi
    
.display:
    ; Draw the string
    mov eax, 0           ; x position
    mov ebx, 0           ; y position  
    mov ecx, edi         ; string pointer
    mov edx, 0x0C        ; color
    call vga_print_string_at
    
    popad
    ret
    
; collision check time
; idea: basically just store x and y of current head coords and compare to each food x and y 
; jump if hit
; great another collision check, this time for the spawn of an apple
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
    je .respawn_apple           ; Changed name
    
.next_apple:
    inc edi
    jmp .check_loop
    
.respawn_apple:
    ; Respawn apple at index EDI immediately
    ; otherwise u overwrite it, more efficient to do that instead of storing it o.0
    call xorshift32
    push eax
    
    movzx eax, ax
    xor edx, edx
    mov ebx, 80
    div ebx
    mov [food_x + edi*4], edx
    
    pop eax
    shr eax, 16
    xor edx, edx
    mov ebx, 25
    div ebx
    mov [food_y + edi*4], edx
    
    ; Redraw apple
    push edi
    mov eax, [food_x + edi*4]
    mov ebx, [food_y + edi*4]
    mov ecx, 'O'
    mov edx, 0x0C
    call vga_write_char_at
    pop edi

	inc dword [snake_len] 

    xor eax, eax
    ret
    
.no_collision:
    mov eax, 1
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
; Issues found
; =============================================================================
apple_race:
	There was a nasty race condition inside of the apple spawn logic and body redraw logic.
	When an apple generates the pseudorandom coordinates for the next spawnpoint, it may overlap with the snakes body
circular_buffer:
	With max_length equ 100, the circular buffer is getting corrupted or overwritten at a certain length, will have to implement a length param to see at which point to correlate the issue

%endif
; ============================================================================
; Include Drivers
; ============================================================================

%include "vga/min_snake_vga.asm"
%include "keyboard/keyboard_driver.asm"
%include "timer/timer_driver.asm"

; ============================================================================
; Data Section
; ============================================================================

; Variables
length_buffer times 11 db 0    

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
paused db 'Paused', 0

; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)
