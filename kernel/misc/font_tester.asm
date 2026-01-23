font_tester:
	mov al, 1
	call mode13_clear_screen
	mov esp, 0x7C00

    mov esi, alphabet
    mov eax, 20
    mov ebx, 10
    mov dl, 100
    call mode13_print_string
    
    mov esi, alphabet
    mov eax, 20
    mov ebx, 30
    mov dl, 100
    call font2_string
    
.loop:
	mov eax, 2000
	call wait_frames
	jmp .loop
	
	
alphabet		      db '0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ', 0
