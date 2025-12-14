g_paused:
    ; Draw pause text
    mov esi, pause_str
    mov eax, 140
    mov ebx, 90
    mov dl, 15
    call mode13_print_string
    
.pause_wait:
    hlt
    mov eax, 310
    mov ebx, 5
    mov ecx, 8
    mov edx, 8
    mov esi, 0
    call mode13_fill_rect
    
    call get_ticks
	call int_to_string
	mov eax, 310
	mov ebx, 5
	mov dl, 15
	call mode13_print_string
    cmp byte [game_running], 1
    jne .pause_wait
    
    ; Erase pause text
    mov eax, 140
    mov ebx, 90
    mov ecx, 60
    mov edx, 20
    mov esi, 0
    call mode13_fill_rect
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

byte_to_hex:
    push eax
    push ebx
    
    ; High nibble
    mov bl, al
    shr bl, 4
    and bl, 0x0F
    cmp bl, 9
    jle .high_digit
    add bl, 'A' - 10
    jmp .high_done
.high_digit:
    add bl, '0'
.high_done:
    mov [hex_buf], bl
    
    ; Low nibble
    mov bl, al
    and bl, 0x0F
    cmp bl, 9
    jle .low_digit
    add bl, 'A' - 10
    jmp .low_done
.low_digit:
    add bl, '0'
.low_done:
    mov [hex_buf + 1], bl
    mov byte [hex_buf + 2], 0
    
    mov esi, hex_buf
    pop ebx
    pop eax
    ret

init_pics:
    ; ICW1: Initialize both PICs
    mov al, 0x11                ; ICW1: Init + ICW4 needed
    out 0x20, al                ; Send to PIC1 command port
    out 0xA0, al                ; Send to PIC2 command port
    
    ; ICW2: Set interrupt vector offsets
    mov al, 0x20                ; PIC1 starts at INT 32 (0x20)
    out 0x21, al                ; PIC1 data port
    mov al, 0x28                ; PIC2 starts at INT 40 (0x28)
    out 0xA1, al                ; PIC2 data port
    
    ; ICW3: Setup cascade
    mov al, 0x04                ; PIC1: slave on IRQ2
    out 0x21, al
    mov al, 0x02                ; PIC2: cascade identity
    out 0xA1, al
    
    ; ICW4: Set mode
    mov al, 0x01                ; 8086 mode
    out 0x21, al
    out 0xA1, al
    
	; OCW1 interrupt masks
	mov al, 0xFC                ; 11111100b - enable ONLY IRQ0, IRQ1
	out 0x21, al
	mov al, 0xFF                ; Mask all on PIC2
	out 0xA1, al
    
    ret
; ============================================================================
; setup_fdc_idt: Set up IDT entry for FDC interrupt (IRQ6 = INT 38)
; ============================================================================
setup_fdc_idt:
    pushad
    
    ; Calculate absolute address of handler
    mov eax, 0x100000
    mov ebx, fdc_irq_handler
    sub ebx, kernel_entry
    add eax, ebx
    
    ; Point to IDT entry 38 (IRQ6)
    mov edi, 0x110000
    add edi, (38 * 8)
    
    mov word [edi], ax
    mov word [edi + 2], 0x08
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E
    shr eax, 16
    mov word [edi + 6], ax
    
    popad
    ret
;==========GLOBAL STRINGS/VARIABLES======
paused 	      db 'PAUSED', 0
	
