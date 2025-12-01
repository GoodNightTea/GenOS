pacman:
    mov esp, 0x7000
	mov al, 0
	call mode13_clear_screen	
	; Input: EAX = x, EBX = y, ecx = height, edx = width
	mov eax, 5
	mov ebx, 5
	mov ecx, 10
	mov edx, 60
	call pacman_pipe_v
	; Input: EAX = x, EBX = y, ecx = width, ebx = height
	add eax, 55
	mov ebx, 5
	mov ecx, 60
	mov edx, 10
	call pacman_pipe_h
	call
.hlt:
	hlt
	mov eax, 10000
	call wait_frames
	jmp .hlt
