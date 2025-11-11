; ============================================================================
; Keyboard Driver for Snake Game
; ============================================================================

; Scancode definitions (make codes - when key is pressed)
SCANCODE_W          equ 0x11
SCANCODE_A          equ 0x1E
SCANCODE_S          equ 0x1F
SCANCODE_D          equ 0x20
SCANCODE_UP         equ 0x48
SCANCODE_LEFT       equ 0x4B
SCANCODE_DOWN       equ 0x50
SCANCODE_RIGHT      equ 0x4D
SCANCODE_ESC        equ 0x01

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
    
    ; Check if it's a break code (key release - bit 7 set)
    test al, 0x80
    jnz .done                       ; Ignore key releases
    
    ; Check for arrow keys or WASD
    cmp al, SCANCODE_RIGHT
    je .set_right
    cmp al, SCANCODE_D
    je .set_right
    
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
