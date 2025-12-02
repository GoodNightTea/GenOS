pacman:
    mov esp, 0x7000
	mov al, 0
	call mode13_clear_screen	
	; Input: EAX = x, EBX = y, ecx = spacing, edx = length
	call mode13_frame

	mov eax, 17
	mov ebx, 2
	mov ecx, 1
	mov esi, 1
	call pacman_270
	mov eax, 17
	mov ebx, 2
	mov ecx, 143
	mov edx, 5
	call pacman_pipe_h
	mov eax, 2
	mov ebx, 18
	mov ecx, 5
	mov edx, 20
	call pacman_pipe_v
	mov eax, 20
	mov ebx, 2
	mov ecx, 270
	mov edx, 1
	call mode13_fill_rect
	
	mov eax, 190
	mov ebx, 2
	mov ecx, 110
	mov edx, 5
	mov esi, 1
	call pacman_pipe_h
	
	mov eax, 158
	mov esi, 1
	call pacman_90.inner_arc
	
	mov eax, 190
	mov esi, 1
	call pacman_270.inner_arc
	
	mov eax, 168
	mov ebx, 18
	mov ecx, 12
	mov edx, 10
	call pacman_pipe_v
	
	mov eax, 300
	mov ebx, 2
	mov esi, 1
	call pacman_90
	
	mov eax, 310
	mov ebx, 18
	mov ecx, 5
	mov edx, 20
	call pacman_pipe_v
	

.hlt:
	hlt
	mov eax, 10000
	call wait_frames
	jmp .hlt
