;; ============================================================================
;; editor.asm
;;
;; In the editor we will remove the use of BIOS interrupt. For video we are
;; using the Video Memory. We still use the keyboard BIOS service but we check
;; how to remove it...
;;
;; Currently we only display a message and wait for a user input. Once user
;; hit a key we return to kenrel. Nothing fancy...

%include "include/constants.asm"

;; ----------------------------------------------------------------------------
;; MAIN
editor:
    ;; In the editor we don't use BIOS interrupts for printing
    ;; message. We use the Video Memory

    ;; Clear the screen
    mov ax, VIDEO_MEMORY
    mov es, ax  ; In real mode segment is shifted so es:0000 => 0xB8000

    mov si, editorHdr   ; display a welcome message
    call print_string

    mov ah, 0x0  ; wait for keypress before jumping back to kernel
    int 0x16     ; BIOS interrupt for keyboard services

jmp_kernel:
    ; before jumping to the kernel we need to setup segments
    mov ax, KERNEL_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    jmp KERNEL_SEG:KERNEL_OFFSET ; far jump to kernel

;; ----------------------------------------------------------------------------
;; FUNCTIONS

print_trampoline:
	call print_char
print_string:
	lodsb		; load DS:SI into AL and increment SI
	or al, al	; "or-ing" will set ZF flags to 0 if al == 0
	jnz print_trampoline ; the trick here is that we jump to the trampoline that
                ; will call the print_char. So when the print_char will return
                ; the next instruction that will be executed is the lodsb.
	            ; else al == 0 and so we reach the end of the string, so just go
                ; to the next line and return (we don't check if we overflow the
                ; video's memory)...
	add byte [ypos], 1 ; we suppose that we don't reach the end of the screen
	mov byte [xpos], 0 ; go to the beginning of the line
	ret

print_char:
	mov ah, 0x1E; 0x1 is for blue background and 0xE is for yellow foreground
	mov cx, ax  ; save attribute (rememer ASCII has been loaded in AL)

	movzx ax, byte [ypos] ; move ypos into ax and extend with zeros
	mov dx, 160           ; There are 2 bytes and 80 columns
	mul dx                ; ax = ax * 160 (the offset computed for y)

	movzx bx, byte [xpos]
	shl bx, 1 ; Shift left is equivalent to mult by 2. As there are 2 bytes
	          ; for attribute if x == 4 then the offset for x is +8

	; So in ax we have the shift according to ypos, in bx we have the shift
	; according to xpos if we add both we have our position :-)
	mov di, 0
	add di, ax
	add di, bx

	mov ax, cx ; restore the attribute (BG, FG, ASCII code)
	stosw      ; Store AX at ES:DI => Print the character

	add byte [xpos], 1 ; Update the position, we don't wrap
	ret

;; ----------------------------------------------------------------------------
;; VARIABLES

editorHdr db "Inside ctd-editor !!!", 0
xpos      db 0
ypos      db 0

	; Sector padding to have a bin generated of 512 bytes (one sector)
	times 512-($-$$) db 0
