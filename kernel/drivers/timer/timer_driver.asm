; ============================================================================
; Timer System using PIT (Programmable Interval Timer)
; ============================================================================

; PIT Constants
PIT_CHANNEL0    equ 0x40        ; Channel 0 data port
PIT_COMMAND     equ 0x43        ; Command register
PIT_FREQUENCY   equ 1193182     ; Base PIT frequency (Hz)

; Timer configuration
TIMER_HZ        equ 60          ; Target frequency (60 Hz = ~16.67ms per tick)

; ============================================================================
; init_timer: Initialize PIT and set up timer interrupt
; ============================================================================
init_timer:
    pushad
    
    ; Calculate divisor for desired frequency
    ; Divisor = PIT_FREQUENCY / TIMER_HZ
    ; For 60 Hz: 1193182 / 60 = 19886 (0x4DAE)
    
    mov ax, PIT_FREQUENCY & 0xFFFF
    mov dx, PIT_FREQUENCY >> 16
    mov cx, TIMER_HZ
    div cx                      ; AX = divisor
    
    push ax                     ; Save divisor
    
    ; Send command byte to PIT
    ; 00 = Channel 0
    ; 11 = Access mode: lobyte/hibyte
    ; 010 = Mode 2 (rate generator)
    ; 0 = Binary mode
    mov al, 0x34                ; 00110100b
    out PIT_COMMAND, al
    
    ; Send divisor to channel 0
    pop ax                      ; Restore divisor
    out PIT_CHANNEL0, al        ; Low byte
    mov al, ah
    out PIT_CHANNEL0, al        ; High byte
    
    popad
    ret

; ============================================================================
; setup_timer_idt: Set up IDT entry for timer interrupt (IRQ0 = INT 32)
; Called after setup_idt, adds timer handler
; ============================================================================
setup_timer_idt:
    pushad
    
    ; Calculate absolute address of timer handler
    mov eax, 0x100000
    mov ebx, timer_handler
    sub ebx, kernel_entry
    add eax, ebx                ; EAX = absolute handler address
    
    ; Point to IDT entry 32 (IRQ0)
    mov edi, 0x110000           ; IDT base
    add edi, (32 * 8)           ; IRQ0 entry
    
    mov word [edi], ax          ; Low 16 bits of handler
    mov word [edi + 2], 0x08    ; Code segment
    mov byte [edi + 4], 0       ; Reserved
    mov byte [edi + 5], 0x8E    ; Present, ring 0, interrupt gate
    shr eax, 16
    mov word [edi + 6], ax      ; High 16 bits of handler
    
    popad
    ret

; ============================================================================
; timer_handler: IRQ0 interrupt handler
; Increments frame counter and sends EOI
; ============================================================================
timer_handler:
    pushad
    
    ; Increment frame counter
    inc dword [timer_ticks]
    
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

; ============================================================================
; wait_frames: Wait for a specific number of timer ticks
; Input: EAX = number of frames to wait
; ============================================================================
wait_frames:
    push ebx
    push ecx
    
    mov ebx, [timer_ticks]      ; Get current tick count
    add ebx, eax                ; EBX = target tick count
    
.wait_loop:
    hlt                         ; Wait for interrupt (saves CPU!)
    mov ecx, [timer_ticks]      ; Get current ticks
    cmp ecx, ebx                ; Have we reached target?
    jl .wait_loop               ; If not, keep waiting
    
    pop ecx
    pop ebx
    ret

; ============================================================================
; get_ticks: Get current timer tick count
; Output: EAX = current tick count
; ============================================================================
get_ticks:
    mov eax, [timer_ticks]
    ret

; ============================================================================
; Data Section
; ============================================================================

timer_ticks     dd 0            ; Frame counter, incremented by timer IRQ
