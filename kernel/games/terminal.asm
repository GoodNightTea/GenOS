terminal:
    mov esp, 0x7000
    mov al, 0
    call mode13_clear_screen
    
    mov dword [column], 0
    mov dword [row], 1
    mov dword [colour], 15
    ; todo: cursor to see where tf you are 
.main:
    sti
    hlt                             
    
    cmp byte [input_buffer], 0xff
    je .main                       
    

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
    je .skip_advance
    

    inc dword [column]
    
.skip_advance:

    mov byte [input_buffer], 0xff
    mov byte [colour], 15
    
    ; Check for line wrap
    cmp dword [column], 38
    jge .next_row
    jmp .main
    
.next_row:
    mov dword [column], 1
    inc dword [row]
    jmp .main

; Data
colour      dd 15
row         dd 0
column      dd 0
input_buffer: db 0, 0
