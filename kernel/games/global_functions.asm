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



;==========GLOBAL STRINGS/VARIABLES======
paused 	      db 'PAUSED', 0
