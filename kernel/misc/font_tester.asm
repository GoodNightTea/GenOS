font_tester:
	mov esp, 0x7C00	

	mov dword [grad_start_idx], 16
	mov dword [grad_end_idx], 32
	mov eax, 0
	mov ebx, 0
	mov ecx, 320
	mov edx, 200
	call draw_gradient_rect
	
	mov esi, alphabet
    mov eax, 10
    mov ebx, 15
    mov dl, 15
    call mode13_print_string
    
    mov esi, first
    mov eax, 10
    mov ebx, 5
    mov dl, 15
    call mode13_print_string
   
    mov esi, second
    mov eax, 10
    mov ebx, 35
    mov dl, 15
    call font2_string


    mov esi, alphabet
    mov eax, 10
    mov ebx, 45
    mov dl, 15
    call font2_string

.loop:
	mov eax, 2000
	call wait_frames
	jmp .loop
	
numbers			  db '0123456789'
alphabet		  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 0
first		      db 'first font', 0
second		      db 'second font', 0
