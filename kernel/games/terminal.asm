terminal:
    mov esp, 0x7000
    mov al, 0
    call mode13_clear_screen
    ; todo: curser? cursor? idk just to see where you are typing
    mov dword [column], 2
    mov dword [row], 1
    mov dword [colour], 15
    mov dword [buffer_offset], 0
    mov dword [current_sector], 0
    mov dword [delete_request], 0
    mov byte [flush_request], 0
    ; Clear the write buffer
    mov edi, WRITE_BUFFER
    mov ecx, 32
    xor al, al
    rep stosb
    	
.main:
    sti
    hlt                             
 
	cmp byte [flush_request], 1
	je .flush
	
.handle_input:

    cmp byte [input_buffer], 0xff
    je .main                     

    ; Erase old character position
    push eax
    mov eax, dword [column]
    imul eax, 8
    mov ebx, dword [row]
    imul ebx, 8
    mov ecx, 8
    mov edx, 8
    mov esi, 0
    call mode13_fill_rect
    pop eax
    
    ; Draw new character
    push eax
    mov eax, dword [column]
    imul eax, 8
    mov ebx, dword [row]
    imul ebx, 8
    mov dl, byte [colour]
    mov esi, input_buffer        
    call mode13_print_string
    pop eax

    cmp byte [colour], 0
    je .delete
    
    mov al, [input_buffer]
    mov edi, WRITE_BUFFER
    add edi, [buffer_offset]
    stosb
    inc dword [buffer_offset]
    
    cmp dword [buffer_offset], 32
    jge .flush
    
    inc dword [column]
    jmp .reset   
    
.continue:
    cmp byte [colour], 1
    je .delete
    inc dword [column]
    
.skip_advance:
    mov byte [input_buffer], 0xff
    mov byte [colour], 15
    
    ; Check for line wrap
    cmp dword [column], 32
    jge .next_row
    jmp .main
 
.delete:
	cmp dword [buffer_offset], 0
	je .reset

	dec dword [buffer_offset]
	jmp .reset
    
.flush:
    call flush_buffer
    mov byte [flush_request], 0 ; flush request handled
    inc dword [column]
    jmp .continue
   
.next_row:
    mov dword [column], 1
    inc dword [row]
    jmp .main

.reset:
    mov byte [input_buffer], 0xff
    mov byte [colour], 15
    
    cmp dword [column], 32
    je .next_row   
    jmp .main
    
    
flush_buffer:
	pushad ; turned to true global 
    ; Write full buffer to disk
    
    mov eax, [current_sector]       ; Which data sector
    mov ecx, 1                      ; 1 sector
    mov esi, WRITE_BUFFER
    call write_data_sectors
    
    ; Clear buffer for next writes
    mov edi, WRITE_BUFFER
    mov ecx, 512
    xor al, al
    rep stosb
    
    mov dword [buffer_offset], 0
    inc dword [current_sector]
    
    popad
    ret

; Data
colour      dd 15
buffer_offset: dd 0
sector:     dd 1
row         dd 0
column      dd 0
input_buffer: db 0, 0
current_sector dd 0
flush_request:	db 0
delete_request	dd 0	
