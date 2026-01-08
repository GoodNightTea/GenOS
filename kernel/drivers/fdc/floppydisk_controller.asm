; ============================================================================
; Floppy Disk Controller (FDC) Driver
; ============================================================================
; For 1.44MB 3.5" floppy disks
; Uses DMA channel 2 and IRQ 6
; DMA Buffer: 0x80000-0x81FFF (8KB reserved)
; ============================================================================

; ============================================================================
; FDC I/O Ports
; ============================================================================
FDC_DOR         equ 0x3F2       ; Digital Output Register
FDC_MSR         equ 0x3F4       ; Main Status Register (read)
FDC_DATA        equ 0x3F5       ; Data FIFO
FDC_CCR         equ 0x3F7       ; Configuration Control Register (write)

; ============================================================================
; DMA Controller Ports (Channel 2)
; ============================================================================
DMA_ADDR_2      equ 0x04
DMA_COUNT_2     equ 0x05
DMA_PAGE_2      equ 0x81
DMA_MASK        equ 0x0A
DMA_MODE        equ 0x0B
DMA_RESET_FF    equ 0x0C

; ============================================================================
; FDC Register Bits
; ============================================================================
; DOR bits
DOR_IRQ_DMA     equ 0x08
DOR_MOTOR_A     equ 0x10

; MSR bits
MSR_RQM         equ 0x80        ; Ready for data transfer
MSR_DIR         equ 0x40        ; Direction: 0=CPU→FDC, 1=FDC→CPU

; ============================================================================
; FDC Commands
; ============================================================================
CMD_SPECIFY         equ 0x03
CMD_RECALIBRATE     equ 0x07
CMD_SENSE_INT       equ 0x08
CMD_READ_DATA       equ 0x06
CMD_WRITE_DATA      equ 0x05
CMD_CONFIGURE       equ 0x13

CMD_MFM             equ 0x40    ; MFM mode bit

; ============================================================================
; Disk Geometry (1.44MB)
; ============================================================================
SECTORS_PER_TRACK   equ 18
HEADS               equ 2
TRACKS              equ 80
BYTES_PER_SECTOR    equ 512

; ============================================================================
; DMA Buffer
; ============================================================================
DMA_BUFFER          equ 0x80000

; ============================================================================
; Error Codes
; ============================================================================
ERR_NONE            equ 0x00
ERR_TIMEOUT         equ 0x01
ERR_SEEK_ERROR      equ 0x02

; ============================================================================
; init_fdc: Initialize FDC
; Returns: AL = 0 on success
; ============================================================================
init_fdc:
    pushad

    ; Reset controller
    call fdc_reset

    ; Configure controller
    call fdc_configure

    ; Set drive parameters
    call fdc_specify

    ; Recalibrate to track 0
    call fdc_recalibrate
    cmp al, 0
    jne .error

    ; Success
    mov esi, fdc_ok_msg
    mov eax, 0
    mov ebx, 170
    mov dl, 10
    call print_cool_string
    popad
	mov al, 0
    ret
    
.error:
    mov esi, fdc_error_msg
    mov eax, 20
    mov ebx, 30	
    mov dl, 4
    call mode13_print_string
    mov eax, 200
    call wait_frames
    popad
    mov al, 1
    ret
; ============================================================================
; fdc_show_status: Display FDC status registers
; ============================================================================
fdc_show_status:
    pushad
    
    ; Read and display MSR
    mov esi, str_msr
    mov eax, 50
    mov ebx, 170
    mov dl, 15
    call print_cool_string
    
    mov dx, FDC_MSR
    in al, dx
    call byte_to_hex
    mov eax, 90
    mov ebx, 170
    mov dl, 15
    call print_cool_string
    
    ; Display ST0 (from result buffer)
    mov esi, str_st0
    mov eax, 50
    mov ebx, 180
    mov dl, 15
    call print_cool_string
    
    mov al, [fdc_result_buffer]
    call byte_to_hex
    mov eax, 90
    mov ebx, 180
    mov dl, 15
    call print_cool_string
    
    ; Display current track
    mov esi, str_track
    mov eax, 50
    mov ebx, 190
    mov dl, 15
    call print_cool_string
    
    mov al, [fdc_result_buffer + 1]
    call byte_to_hex
    mov eax, 90
    mov ebx, 190
    mov dl, 15
    call print_cool_string
    
    popad
    ret



; ============================================================================
; fdc_reset: Reset the FDC
; ============================================================================
fdc_reset:
    pushad
    
    ; Disable controller
    mov dx, FDC_DOR
    xor al, al
    out dx, al
    
    ; Wait
    mov eax, 10
    call delay_ms
    
    ; Enable: IRQ/DMA + drive 0
    mov al, 0x0C
    out dx, al
    
    ; Wait for ready
    mov eax, 100
    call delay_ms
    
    ; Clear IRQ flag
    mov byte [fdc_irq_fired], 0
    
    ; Handle reset interrupts (4 sense commands)
    mov ecx, 4
.sense_loop:
    push ecx
    call fdc_sense_interrupt
    pop ecx
    loop .sense_loop
    
    popad
    ret

; ============================================================================
; fdc_configure: Send CONFIGURE command
; ============================================================================
fdc_configure:
    pushad
    
    mov al, CMD_CONFIGURE
    call fdc_write_byte
    
    mov al, 0x00
    call fdc_write_byte
    
    mov al, 0x57            ; FIFO on, polling off
    call fdc_write_byte
    
    mov al, 0x00
    call fdc_write_byte
    
    popad
    ret

; ============================================================================
; fdc_specify: Send SPECIFY command (set timings)
; ============================================================================
fdc_specify:
    pushad
    
    mov al, CMD_SPECIFY
    call fdc_write_byte
    
    mov al, 0xDF            ; Step rate, head unload
    call fdc_write_byte
    
    mov al, 0x02            ; Head load, DMA mode
    call fdc_write_byte
    
    popad
    ret

; ============================================================================
; fdc_recalibrate: Seek to track 0
; Returns: AL = 0 on success
; ============================================================================
fdc_recalibrate:
    pushad
    
    ; Turn motor on
    call fdc_motor_on
    
    ; Clear IRQ
    mov byte [fdc_irq_fired], 0
    
    ; Send command
    mov al, CMD_RECALIBRATE
    call fdc_write_byte
    
    mov al, 0               ; Drive 0
    call fdc_write_byte
    
    ; Wait for interrupt
    call fdc_wait_irq
    
    ; Get result
    call fdc_sense_interrupt
    
    ; Check status (ST0 = 0x20 = seek complete)
    mov al, [fdc_result_buffer]
    and al, 0xF0
    cmp al, 0x20
    je .success
    
    popad
    mov al, ERR_SEEK_ERROR
    ret
    
.success:
    popad
    xor al, al
    ret

; ============================================================================
; fdc_sense_interrupt: Get interrupt status
; ============================================================================
fdc_sense_interrupt:
    pushad
    
    mov al, CMD_SENSE_INT
    call fdc_write_byte
    
    call fdc_read_byte
    mov [fdc_result_buffer], al
    
    call fdc_read_byte
    mov [fdc_result_buffer + 1], al
    
    popad
    ret

; ============================================================================
; fdc_motor_on: Turn on motor for drive 0
; ============================================================================
fdc_motor_on:
    pushad
    
    ; DOR: IRQ/DMA + Motor A + Drive 0
    mov dx, FDC_DOR
    mov al, 0x1C            ; 0001 1100
    out dx, al
    
    ; Wait for spinup
    mov eax, 30
    call delay_ms
    
    popad
    ret

; ============================================================================
; fdc_motor_off: Turn off motor
; ============================================================================
fdc_motor_off:
    pushad
    
    mov dx, FDC_DOR
    mov al, 0x0C            ; IRQ/DMA only
    out dx, al
    
    popad
    ret

; ============================================================================
; fdc_write_byte: Write byte to FDC
; Input: AL = byte
; ============================================================================
fdc_write_byte:
    push ebx
    push ecx
    push edx
    
    mov bl, al              ; Save byte
    mov ecx, 500            ; Timeout
    
.wait:
    mov dx, FDC_MSR
    in al, dx
    test al, MSR_RQM
    jnz .ready
    
    push eax
    mov eax, 1
    call delay_ms
    pop eax
    
    dec ecx
    jnz .wait
    jmp .done
    
.ready:
    test al, MSR_DIR        ; Check direction
    jnz .done               ; Wrong direction
    
    mov dx, FDC_DATA
    mov al, bl
    out dx, al
    
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================================================
; fdc_read_byte: Read byte from FDC
; Output: AL = byte
; ============================================================================
fdc_read_byte:
    push ebx
    push ecx
    push edx
    
    mov ecx, 500
    
.wait:
    mov dx, FDC_MSR
    in al, dx
    test al, MSR_RQM
    jnz .ready
    
    push eax
    mov eax, 1
    call delay_ms
    pop eax
    
    dec ecx
    jnz .wait
    
    xor al, al
    jmp .done
    
.ready:
    test al, MSR_DIR
    jz .done
    
    mov dx, FDC_DATA
    in al, dx
    
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================================================
; fdc_wait_irq: Wait for IRQ6
; ============================================================================
fdc_wait_irq:
    push ecx
    
    mov ecx, 10           ; 1 second timeout
    
.wait:
    cmp byte [fdc_irq_fired], 1
    je .done
    
    push eax
    mov eax, 1
    call delay_ms
    pop eax
    
    dec ecx
    jnz .wait
    
.done:
    mov byte [fdc_irq_fired], 0
    pop ecx
    ret

fdc_write_sector:
    pushad
    
    mov [write_track], al
    mov [write_head], ah
    mov [write_sector], bl
    
    call fdc_motor_on
    
    mov ecx, 512
    call setup_dma_write
    
    mov byte [fdc_irq_fired], 0
    
    mov al, CMD_WRITE_DATA | CMD_MFM
    call fdc_write_byte
    
    mov al, [write_head]
    shl al, 2
    call fdc_write_byte
    
    mov al, [write_track]
    call fdc_write_byte
    
    mov al, [write_head]
    call fdc_write_byte
    
    mov al, [write_sector]
    call fdc_write_byte
    
    mov al, 2
    call fdc_write_byte
    
    mov al, 18
    call fdc_write_byte
    
    mov al, 0x1B
    call fdc_write_byte
    
    mov al, 0xFF
    call fdc_write_byte
    
    call fdc_wait_irq
    
    ; Read results
    call fdc_read_byte
    mov [fdc_result_buffer], al
    call fdc_read_byte
    call fdc_read_byte
    call fdc_read_byte
    call fdc_read_byte
    call fdc_read_byte
    call fdc_read_byte
    
    ; Check error
    mov al, [fdc_result_buffer]
    and al, 0xC0
    cmp al, 0
    jne .error
    
    popad
    xor al, al
    ret
    
.error:
    popad
    mov al, 1
    ret

; ============================================================================
; fdc_irq_handler: IRQ6 handler
; ============================================================================
fdc_irq_handler:
    pushad
    
    mov byte [fdc_irq_fired], 1
    
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

; ============================================================================
; Data Section
; ============================================================================

write_track:     db 0
write_head:      db 0
write_sector:    db 0	

fdc_ok_msg:         db 'FDC OK', 0
fdc_error_msg:      db 'FDC ERROR', 0
str_msr:    db 'MSR:', 0
str_st0:    db 'ST0:', 0
str_track:  db 'TRK:', 0

fdc_irq_fired:      db 0
hex_buf:    times 3 db 0
fdc_result_buffer:  times 7 db 0
