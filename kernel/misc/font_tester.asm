font_tester:
	mov esp, 0x7C00	
  	pushad
  	
	mov byte [grad_start_r], 63    ; Orange
	mov byte [grad_start_g], 32
	mov byte [grad_start_b], 0
	mov byte [grad_end_r], 40      ; Purple
	mov byte [grad_end_g], 0
	mov byte [grad_end_b], 50
	mov dword [grad_palette_start], 16
	mov dword [grad_num_colors], 240
	call setup_custom_gradient
	mov eax, 0
   	mov ebx, 0
   	mov ecx, 320
   	mov edx, 200
	mov dword [grad_start_idx], 16
	mov dword [grad_end_idx], 240
	call draw_gradient_rect
	mov eax, 10
    call wait_frames
    
	popad
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
