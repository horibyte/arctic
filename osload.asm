; osload.asm
; Horibyte Arctic-ReKanto Kernel Loader
; Copyright (c) 2025 Horibyte

[org 0x0000]    ; This code will be loaded at LOAD_ADDRESS (e.g., 0x8000),
                ; so it starts at 0x0000 relative to that load address.
bits 16         ; We are still in 16-bit Real Mode when this code starts executing.

start_osload:
    ; Set up segment registers
    ; We need to know the segment where we were loaded (0x8000 from bootloader)
    mov ax, cs      ; CS already contains 0x8000 from the JMP in bootloader
    mov ds, ax      ; Set DS to 0x8000 so data accesses work correctly
    mov es, ax      ; Set ES to 0x8000 if needed for any ES: based operations
    ; For stack, setting SS to 0x0000 and SP to 0x7FF0 is generally okay if
    ; it doesn't conflict with BIOS or bootloader original area.
    xor ax, ax      ; Clear AX to set SS.
    mov ss, ax      ; Set SS to 0x0000 (stack will be in lower memory)
    mov sp, 0x7FF0  ; Stack Pointer for 0x0000:0x7FF0 (or just below 0x8000:0x0000)

    ; Clear the screen (optional, but good for visual confirmation)
    mov ax, 0x0600  ; AH=06h (scroll window up), AL=00h (clear window)
    mov bh, 0x07    ; BH=07h (attribute: white on black)
    xor cx, cx      ; CH=0, CL=0 (upper-left corner row 0, col 0)
    mov dx, 0x184f  ; DH=24, DL=79 (lower-right corner row 24, col 79)
    int 0x10        ; Call BIOS video services

    ; --- Print "Horibyte Arctic [Version 0.1.3]" ---
    mov si, os_version_msg
    call print_string_osload

    ; --- REMOVED: Blank line between version and success message ---

    ; --- Print success message (Horibyte Arctic-ReKanto Kernel Load Success & Copyright) ---
    mov si, osload_success_msg
    call print_string_osload

    ; --- Print a blank line AFTER the copyright, BEFORE the halted message ---
    mov si, newline_char
    call print_string_osload

    ; --- Print "No more functions for this operation have been defined, system halted." ---
    mov si, halted_msg
    call print_string_osload

    ; --- Future steps for osload.asm ---
    ; Will involve setting up GDT, Protected Mode, loading rkrnl.bin, etc.

    jmp $           ; Infinite loop for now

; --- Helper Function to Print String ---
print_string_osload:
    mov ah, 0x0e        ; BIOS teletype function (display character, advance cursor)
.loop:
    lodsb               ; Load byte from DS:SI into AL, increment SI
    or al, al           ; Check if AL is zero (end of string)
    jz .done            ; If zero, jump to done
    int 0x10            ; Otherwise, print the character
    jmp .loop           ; Loop back
.done:
    ret                 ; Return from function

; --- Data Messages ---
os_version_msg      db 'Horibyte Arctic [Version 0.1.3]', 0x0d, 0x0a, 0

; A simple string with just a newline for blank lines
newline_char        db 0x0d, 0x0a, 0

osload_success_msg  db 'Horibyte Arctic-ReKanto Kernel Load Success', 0x0d, 0x0a
                    db 'Copyright (c) 2025 Horibyte', 0x0d, 0x0a, 0

halted_msg          db 'No more functions for this operation have been defined, system halted.', 0x0d, 0x0a, 0

; --- Padding (if needed to fill sectors, but not required for function) ---
; Ensure this kernel fits within the expected size for your bootloader to load.
; If your bootloader loads exactly one 512-byte sector, you might need to
; add padding here.
; Example for 512-byte sector:
; times 512 - ($ - $$) db 0