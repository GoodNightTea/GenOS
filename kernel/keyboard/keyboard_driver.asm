; ============================================================================
; Keyboard Driver for Snake Game
; ============================================================================

; Scancode definitions (make codes - when key is pressed)
SCANCODE_1          equ 0x02
SCANCODE_2          equ 0x03
SCANCODE_3          equ 0x04
SCANCODE_4          equ 0x05

SCANCODE_W          equ 0x11
SCANCODE_A          equ 0x1E
SCANCODE_S          equ 0x1F
SCANCODE_S_RELEASE  equ 0x9F
SCANCODE_D          equ 0x20
SCANCODE_UP         equ 0x48
SCANCODE_LEFT       equ 0x4B
SCANCODE_DOWN       equ 0x50
SCANCODE_RIGHT      equ 0x4D
SCANCODE_ESC        equ 0x01
SCANCODE_R			equ 0x13

; Direction constants
DIR_RIGHT           equ 0
DIR_UP              equ 1
DIR_LEFT            equ 2
DIR_DOWN            equ 3

; ============================================================================
; process_scancode: Process keyboard scancode and update direction
; Input: AL = scancode from port 0x60
; ============================================================================
process_scancode:
    pushad
    
    ; Store scancode for debugging
    mov [last_scancode], al
    cmp byte [is_tetris], 1
    je .tetris_input
    ; Check if it's a break code (key release - bit 7 set)
    test al, 0x80
    jnz .done
    
    ; Check for arrow keys or WASD and R
    cmp al, SCANCODE_RIGHT
    je .set_right
    cmp al, SCANCODE_D
    je .set_right
    
    cmp al, SCANCODE_1
    je .menu_choice_1
    cmp al, SCANCODE_2
    je .menu_choice_2
    
    cmp al, SCANCODE_R
    je .triple_fault
    
    cmp al, SCANCODE_UP
    je .set_up
    cmp al, SCANCODE_W
    je .set_up
    
    cmp al, SCANCODE_LEFT
    je .set_left
    cmp al, SCANCODE_A
    je .set_left
    
    cmp al, SCANCODE_S
    je .set_down
    
    cmp al, SCANCODE_ESC
    je .handle_esc
    
    jmp .done
    

.tetris_input:	
    cmp al, SCANCODE_S
    je .tetris_s_press
    cmp al, SCANCODE_S_RELEASE
    je .tetris_s_release
    cmp al, SCANCODE_W
    je .tetris_w
    cmp al, SCANCODE_A
    je .tetris_a
    cmp al, SCANCODE_D
    je .tetris_d
    
    jmp .done
 
.tetris_s_press:
    cmp byte [s_pressed], 1    
    je .done           			
    mov byte [s_pressed], 1
    sub dword [speed], 4        
    jmp .done

.tetris_s_release:
    cmp byte [s_pressed], 0  
    je .done_released
    mov byte [s_pressed], 0
    add dword [speed], 4      
    
    jmp .done
.done_released:
    mov al, 0x20
    out 0x20, al
    popad
    iret
.tetris_w:
	jmp .done
	
.tetris_a:
    cmp dword [current_x_index], 0
    je .done                ; Already at left edge
    dec dword [current_x_index]
    
    mov eax, [current_x_index]
    imul eax, 8
    add eax, 120
    mov [current_piece_x], eax
    jmp .done


.tetris_d:
    cmp dword [current_x_index], 9
    jge .done                
	inc dword [current_x_index]
	mov eax, [current_x_index]
	imul eax, 8
	add eax, 120
	mov [current_piece_x], eax
    
    jmp .done
.menu_choice_1:
    mov byte [menu_choice], 1
    jmp .done
    
.menu_choice_2:
	xor byte [is_tetris], 1
    mov byte [menu_choice], 2
    jmp .done

	
.triple_fault:
	xor eax, eax
	mov [idt_desc + 2], eax  ; Set IDT base to 0x00000000
	lidt [idt_desc]           ; Load garbage IDT

	int 0x00                  ; Trigger divide by zero
	; success >:)


.set_right:
    ; Prevent 180-degree turns
    mov al, [current_direction]
    cmp al, DIR_LEFT
    je .done
    mov byte [current_direction], DIR_RIGHT
	jmp .done

.set_up:

    ; Prevent 180-degree turns
    mov al, [current_direction]
    cmp al, DIR_DOWN
    je .done
    mov byte [current_direction], DIR_UP
    jmp .done

.set_left:

    ; Prevent 180-degree turns
    mov al, [current_direction]
    cmp al, DIR_RIGHT
    je .done
    mov byte [current_direction], DIR_LEFT
    jmp .done

.set_down:

    ; Prevent 180-degree turns
    mov al, [current_direction]
    cmp al, DIR_UP
    je .done
    mov byte [current_direction], DIR_DOWN
    jmp .done

.handle_esc:
    xor byte [game_running], 1       ; Flip bit: 0→1 or 1→0
.done:

    popad
    ret
; ============================================================================
; get_direction_delta: Get X and Y delta based on current direction
; Output: EAX = delta_x, EBX = delta_y
; ============================================================================
get_direction_delta:
    push ecx
    
    movzx ecx, byte [current_direction]
    
    cmp ecx, DIR_RIGHT
    je .right
    cmp ecx, DIR_UP
    je .up
    cmp ecx, DIR_LEFT
    je .left
    cmp ecx, DIR_DOWN
    je .down
    
    ; Default: right
.right:
    mov eax, 1
    mov ebx, 0
    jmp .done

.up:
    mov eax, 0
    mov ebx, -1
    jmp .done

.left:
    mov eax, -1
    mov ebx, 0
    jmp .done

.down:
    mov eax, 0
    mov ebx, 1
    jmp .done

.done:
    pop ecx
    ret

; ============================================================================
; Data Section
; ============================================================================

current_direction   db DIR_RIGHT        ; Starting direction
last_scancode       db 0                ; For debugging
game_running        db 1                ; Game state flag
menu_choice 		db 0
is_tetris			db 0				; check if its tetris or nah
s_pressed 			db 0
