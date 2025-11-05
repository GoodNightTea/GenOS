
[BITS 32]
[ORG 0x100000]

kernel_entry:
    ; Setup stack at a safer location
    mov esp, 0x7C00         ; Use the old bootloader location (no longer needed)
    cli
    
    ; Setup IDT FIRST (before enabling interrupts)
    call setup_idt
    
     
    ; Read back the handler address from IDT entry 33
    mov esi, 0x110000
    add esi, (33 * 8)
    mov ax, [esi]           ; Low 16 bits
    mov dx, [esi + 6]       ; High 16 bits
    ; If this matches keyboard_handler address, we're good
    
    ; Initialize PICs
    call init_pics
    
    ; NOW safe to enable interrupts
    sti
    
    ; Test 1: Clear and print
    mov eax, 0x00
    call vga_clear_screen
    
    mov eax, 20
    mov ebx, 5
    mov ecx, test1_msg
    mov edx, 0x0E
    call vga_print_string_at
    
    mov eax, 15
    mov ebx, 8
    mov ecx, rect_msg
    mov edx, 0x0F
    call vga_print_string_at
.game:
    pushad
    
    ; Draw snake segments
    mov eax, edi
    mov ebx, 10
    mov ecx, 3
    mov edx, 1
    mov esi, ' '
    call vga_fill_rect
    
    add edi, 0x01
    call wait_for_key
    je .game
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
    
    ; VISUAL DEBUG: Write something to screen to prove we got here
    mov edi, VGA_BUFFER
    mov eax, 0x4F21        ; '!' in white on red
    mov [edi], ax
    
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

test1_msg       db 'Test 1: VGA Functions & Snake Simulation', 0
dt_setup_msg   db 'IDT initialized', 0
rect_msg        db 'Drawing rectangles (snake segments):', 0
test2_msg       db 'Test 2: Screen Clearing Works!', 0
test3_msg       db 'Test 3: Character Positioning Test', 0
skip_msg        db '(Grid test skipped - press key)', 0
press_key_msg   db 'Press any key to continue...', 0
success_msg     db 'All VGA Tests Passed!', 0
ready_msg       db 'Driver ready for Snake game!', 0

; Variables
key_pressed     db 0
test_x          dd 0
test_y          dd 0

; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)

; Note: IDT is now at fixed location 0x110000, not in kernel binary
