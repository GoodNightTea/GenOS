; ============================================================================
; lba_to_chs: Convert logical sector to Track/Head/Sector
; Input: EAX = LBA (logical sector, 0-2879 for 1.44MB)
; Output: 
;   AL = track (0-79)
;   AH = head (0-1)
;   BL = sector (1-18)
; ============================================================================
lba_to_chs:
    push ecx
    push edx
    
    ; Track = LBA / (heads * sectors_per_track)
    ; Head = (LBA / sectors_per_track) % heads
    ; Sector = (LBA % sectors_per_track) + 1
    
    xor edx, edx
    mov ecx, SECTORS_PER_TRACK
    div ecx                     ; EAX = LBA / 18, EDX = LBA % 18
    
    mov bl, dl
    inc bl                      ; Sector = remainder + 1
    
    xor edx, edx
    mov ecx, HEADS
    div ecx                     ; EAX = track, EDX = head
    
    mov ah, dl                  ; Head
    ; AL already = track
    
    pop edx
    pop ecx
    ret

; ============================================================================
; read_sectors: Read multiple sequential sectors
; Input:
;   EAX = starting LBA
;   ECX = number of sectors to read
;   EDI = destination buffer
; Output:
;   AL = 0 on success
; ============================================================================
read_sectors:
    pushad
    
    mov [rs_lba], eax
    mov [rs_count], ecx
    mov [rs_dest], edi
    
.read_loop:
    cmp dword [rs_count], 0
    je .success
    
    ; Convert LBA to CHS
    mov eax, [rs_lba]
    call lba_to_chs
    
    ; Read sector
    call fdc_read_sector
    cmp al, 0
    jne .error
    
    ; Copy from DMA buffer to destination
    push esi
    push edi
    push ecx
    
    mov esi, DMA_BUFFER
    mov edi, [rs_dest]
    mov ecx, 512
    rep movsb
    
    mov [rs_dest], edi      ; Update destination
    
    pop ecx
    pop edi
    pop esi
    
    ; Next sector
    inc dword [rs_lba]
    dec dword [rs_count]
    jmp .read_loop
    
.success:
    popad
    xor al, al
    ret
    
.error:
    popad
    mov al, 1
    ret

rs_lba:     dd 0
rs_count:   dd 0
rs_dest:    dd 0
