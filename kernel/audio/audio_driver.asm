play_tone:
	; input eax = tone
    push eax
    mov ebx, 1193180  ; PIT base frequency
    xor edx, edx
    div ebx           ; divisor = 1193180 / frequency
    
    out 0x43, al      ; command byte
    mov al, 0xB6
    out 0x43, al
    
    pop eax
    out 0x42, al      ; low byte of divisor
    mov al, ah
    out 0x42, al      ; high byte
    
    in al, 0x61       ; enable speaker
    or al, 3
    out 0x61, al
    ret

; Stop tone
stop_tone:
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret
