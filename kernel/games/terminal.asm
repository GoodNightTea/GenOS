terminal:
    mov esp, 0x7000
    mov al, 0
    call mode13_clear_screen
    
    mov dword [term_x_pos], 10     
    
.main:
    sti
    hlt                             
    

    cmp byte [input_buffer], 0
    je .main                       
    
    
    mov al, [input_buffer]
    mov [previous_input], al      
    
    push eax
    mov eax, [term_x_pos]               
    mov ebx, 170			           
    mov dl, 15                      
    mov esi, input_buffer        
    call mode13_print_string                  
    pop eax
    
    ; next char
    add dword [term_x_pos], 8
    
	; under construction
	; cmp byte [input_buffer], 'Q'

    mov byte [input_buffer], 0
    
    jmp .main


; Data
size					dd 0
filename				db "TSET", 0
input_buffer:       db 0, 0            
previous_input:     db 0           
term_x_pos:         dd 10           
file_buffer:    times 10 db 0
