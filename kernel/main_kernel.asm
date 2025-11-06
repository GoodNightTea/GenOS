; most advanced snake simulator in existence
[BITS 32]
[ORG 0x100000]
kernel_entry:
    mov esp, 0x7C00
    cli
    
    call setup_idt
    call init_pics
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
    je .game_over
    
    ; Calculate new head position
    mov eax, [snake_head]
    mov ebx, eax
    shl ebx, 2                      ; × 4 for dword indexing
    
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
    ; Advance head index (circular)
    inc dword [snake_head]
    mov eax, [snake_head]
    cmp eax, max_length
    jl .no_wrap_head
    mov dword [snake_head], 0       ; Wrap around
.no_wrap_head:
    
    ; Store new head position
    mov eax, [snake_head]
    shl eax, 2
    mov [snake_x + eax], ecx
    mov [snake_y + eax], edx
    
    ; Erase tail
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
    
    ; Advance tail index (circular)
    inc dword [snake_tail]
    mov eax, [snake_tail]
    cmp eax, max_length
    
    jl .no_wrap_tail
    mov dword [snake_tail], 0
.no_wrap_tail:
    
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
    
    ; Add a delay so you can see the movement
    mov ecx, 5000000
.delay:
    dec ecx
    jnz .delay
    
    jmp .game

.game_over:
    ; Print game over message
    mov eax, 30
    mov ebx, 12
    mov ecx, game_over_msg
    mov edx, 0x0C                   ; Bright red
    call vga_print_string_at
    
    ; Halt
    cli
    hlt

; ============================================================================
; Helper Functions
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
    

; ============================================================================
; Include Drivers
; ============================================================================

%include "vga/min_snake_vga.asm"
%include "keyboard/keyboard_driver.asm"

; ============================================================================
; Data Section
; ============================================================================

; Variables
max_length    equ 100
snake_x       times 100 dd 0
snake_y       times 100 dd 0
snake_head    dd 3
snake_tail    dd 0
snake_len     dd 4

game_over_msg db 'GAME OVER - Press any key to exit', 0

; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)
