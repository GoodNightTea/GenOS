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
    ; Calculate new head position
    mov eax, [snake_head]
    mov ebx, eax
    shl ebx, 2                      ; × 4 for dword indexing
    
    ; Get current head position
    mov ecx, [snake_x + ebx]
    mov edx, [snake_y + ebx]
    
    ; Move based on direction (example: move right)
    inc ecx                         ; new_x = old_x + 1
    
    ; wrap around edges
    cmp ecx, 80
    jl .no_wrap_x
    mov ecx, 0
.no_wrap_x:
	cmp edx, 25
	jl .no_wrap_y
	mov edx, 0
.no_wrap_y:
    
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
    call wait_for_key
    jmp .game
    
    ; Add a delay so you can see the movement
    mov ecx, 500000
.delay:
    dec ecx
    jnz .delay
    
    jmp .game               

; ============================================================================
; Helper Functions
; ============================================================================

wait_for_key:
    pushad
    
    ; Disable interrupts while setting up
    cli
    mov byte [key_pressed], 0
    
    ; Now enable interrupts and immediately halt
    sti
    
.wait:
    hlt                             ; Wait for interrupt
    
    ; Check if key was pressed
    cli                             ; Disable while checking
    cmp byte [key_pressed], 0
    je .enable_and_wait
    
    ; Key was pressed, we're done
    ; Debounce delay
    mov ecx, 500000
    
.delay:
    dec ecx
    jnz .delay
    
    popad
    ret

.enable_and_wait:
    sti                             ; Re-enable and loop
    jmp .wait

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
    
    ; Read scancode (clears keyboard buffer)
    in al, 0x60
    
    ; Set flag
    mov byte [key_pressed], 1
    
    ; Send EOI
    mov al, 0x20
    out 0x20, al
    
    popad
    iret
    

; ============================================================================
; Include VGA Driver
; ============================================================================

%include "vga/min_snake_vga.asm"

; ============================================================================
; Data Section
; ============================================================================




; Variables
max_length    equ 100
key_pressed   db 0
snake_x       times 100 dd 0
snake_y       times 100 dd 0
snake_head    dd 3
snake_tail    dd 0
snake_len     dd 4
snake_dir	  dd 0


; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)

