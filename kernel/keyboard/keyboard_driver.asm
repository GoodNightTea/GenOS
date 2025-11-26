; ============================================================================
; Keyboard Driver for GenOS
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
SCANCODE_R          equ 0x13
SCANCODE_SPACE      equ 0x39

; Direction constants (for snake)
DIR_RIGHT           equ 0
DIR_UP              equ 1
DIR_LEFT            equ 2
DIR_DOWN            equ 3

; ============================================================================
; process_scancode: Process keyboard scancode
; Input: AL = scancode from port 0x60
; ============================================================================
process_scancode:
    pushad
    
    ; Store scancode for debugging
    mov [last_scancode], al
    
    ; Check if we're in tetris mode
    cmp byte [is_tetris], 1
    je .tetris_input
    
    ; ---- SNAKE/MENU INPUT ----
    
    ; Check if it's a break code (key release - bit 7 set)
    test al, 0x80
    jnz .done
    
    ; Check for arrow keys or WASD
    cmp al, SCANCODE_RIGHT
    je .set_right
    cmp al, SCANCODE_D
    je .set_right
    
    cmp al, SCANCODE_1
    je .menu_choice_1
    cmp al, SCANCODE_2
    je .menu_choice_2
    cmp al, SCANCODE_3
    je .menu_choice_3
    
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
    
    cmp al, SCANCODE_DOWN
    je .set_down
    cmp al, SCANCODE_S
    je .set_down
    
    cmp al, SCANCODE_ESC
    je .handle_esc
    
    jmp .done

; ============================================================================
; TETRIS INPUT HANDLING
; ============================================================================
.tetris_input:
    ; Handle soft drop (S key press/release)
    cmp al, SCANCODE_S
    je .tetris_soft_drop_on
    cmp al, SCANCODE_S_RELEASE
    je .tetris_soft_drop_off
    cmp al, SCANCODE_DOWN
    je .tetris_soft_drop_on
    cmp al, 0xD0                    ; Down arrow release
    je .tetris_soft_drop_off
    
    ; Ignore other release codes
    test al, 0x80
    jnz .done
    
    ; Movement keys
    cmp al, SCANCODE_A
    je .tetris_left
    cmp al, SCANCODE_LEFT
    je .tetris_left
    
    cmp al, SCANCODE_D
    je .tetris_right
    cmp al, SCANCODE_RIGHT
    je .tetris_right
    
    ; Rotation
    cmp al, SCANCODE_W
    je .tetris_rotate
    cmp al, SCANCODE_UP
    je .tetris_rotate
    cmp al, SCANCODE_SPACE
    je .tetris_rotate
    
    ; Pause
    cmp al, SCANCODE_ESC
    je .handle_esc
    
    ; Reset
    cmp al, SCANCODE_R
    je .triple_fault
    
    jmp .done

.tetris_left:
    call tetris_move_left
    jmp .done

.tetris_right:
    call tetris_move_right
    jmp .done

.tetris_rotate:
    call tetris_rotate
    jmp .done

.tetris_soft_drop_on:
    call tetris_soft_drop_start
    jmp .done

.tetris_soft_drop_off:
    call tetris_soft_drop_stop
    jmp .done

; ============================================================================
; MENU CHOICES
; ============================================================================
.menu_choice_1:
    mov byte [menu_choice], 1
    jmp .done
    
.menu_choice_2:
    mov byte [is_tetris], 1
    mov byte [menu_choice], 2
    jmp .done

.menu_choice_3:
    mov byte [menu_choice], 3
    jmp .done

; ============================================================================
; TRIPLE FAULT (reset)
; ============================================================================
.triple_fault:
    xor eax, eax
    mov [idt_desc + 2], eax
    lidt [idt_desc]
    int 0x00

; ============================================================================
; SNAKE DIRECTION HANDLING
; ============================================================================
.set_right:
    mov al, [current_direction]
    cmp al, DIR_LEFT
    je .done
    mov byte [current_direction], DIR_RIGHT
    jmp .done

.set_up:
    mov al, [current_direction]
    cmp al, DIR_DOWN
    je .done
    mov byte [current_direction], DIR_UP
    jmp .done

.set_left:
    mov al, [current_direction]
    cmp al, DIR_RIGHT
    je .done
    mov byte [current_direction], DIR_LEFT
    jmp .done

.set_down:
    mov al, [current_direction]
    cmp al, DIR_UP
    je .done
    mov byte [current_direction], DIR_DOWN
    jmp .done

; ============================================================================
; PAUSE/UNPAUSE
; ============================================================================
.handle_esc:
    xor byte [game_running], 1

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

.done:
    pop ecx
    ret

; ============================================================================
; Data Section
; ============================================================================

current_direction   db DIR_RIGHT
last_scancode       db 0
game_running        db 1
menu_choice         db 0
is_tetris           db 0
is_pong				db 0
s_pressed           db 0
