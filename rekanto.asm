; ******************************************************************
; *                                                                *
; * Horibyte Arctic32 ReKanto32 Kernel                             *
; * Self-explanatory                                               *
; * Copyright (c) 2025 Horibyte                                    *
; *                                                                *
; ******************************************************************

; shitty kernel moment


[org 0x101000] ; Starts at 0x100000
bits 16 ; how did we get here

; --- CONSTANTS ---
MAX_COMMAND_LEN equ 64  ; Maximum length of command user can type
VGA_TEXT_MODE_ADDR equ 0xB8000 ; Video memory address for text mode
DEFAULT_CHAR_ATTR equ 0x07    ; White on black

; --- GLOBAL VARIABLES  ---
current_cursor_pos_x dd 0 ; Current column (0-79)
current_cursor_pos_y dd 0 ; Current row (0-24)

; --- ENTRY POINT OF REKANTO.ASM ---
rekanto_entry_point:
    ; Segment registers should already be set by osload.asm
    ; Stack should already be set by osload.asm

    ; Clear screen again after bootscreen, for clean CLI
    call clear_screen_rekanto

    ; Initial CLI message
    mov esi, welcome_cli_msg
    call print_string_rekanto
    mov esi, newline_char_rekanto ; Blank line after welcome
    call print_string_rekanto

    ; --- Main CLI Loop ---
cli_loop_rekanto:
    mov esi, prompt_msg_rekanto  ; Display the prompt
    call print_string_rekanto

    ; Read command from user
    mov edi, input_buffer_rekanto ; Store input starting here
    xor ecx, ecx                  ; ECX = 0 (current input length)
    call read_input_line_rekanto ; Read a line of input

    ; A blank line after input for better readability
    mov esi, newline_char_rekanto
    call print_string_rekanto

    ; --- Process Command ---
    ; Point ESI to the user's input buffer for comparisons
    mov esi, input_buffer_rekanto

    ; Compare full string for exact matches (help, clear, shutdown, ver)
    mov ebx, help_cmd_str_rekanto
    call compare_strings_rekanto
    jc .is_help_rekanto
    
    mov ebx, clear_cmd_str_rekanto
    call compare_strings_rekanto
    jc .is_clear_rekanto

    mov ebx, shutdown_cmd_str_rekanto
    call compare_strings_rekanto
    jc .is_shutdown_rekanto

    mov ebx, ver_cmd_str_rekanto     ; Check for "ver" command
    call compare_strings_rekanto
    jc .is_ver_rekanto

    ; --- Handle "echo" command specifically ---
    ; Check if input starts with "echo "
    mov ebx, echo_cmd_prefix_rekanto ; Points to "echo "
    call compare_prefix_rekanto      ; New function to check prefix match
    jc .is_echo_cmd_rekanto          ; If CF is set, it matches "echo "

    ; Handle "echo" command with no arguments ("echo" followed by Enter)
    mov ebx, echo_cmd_str_rekanto    ; Points to "echo" (no trailing space)
    call compare_strings_rekanto     ; Check for exact "echo" command
    jc .is_echo_no_arg_rekanto

    ; If command not recognized
    mov esi, unknown_cmd_msg_rekanto
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_help_rekanto:
    mov esi, help_msg_rekanto
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_clear_rekanto:
    call clear_screen_rekanto
    jmp cli_loop_rekanto

.is_echo_cmd_rekanto:
    ; ESI is already pointing to input_buffer_rekanto from above
    ; It means input starts with "echo ", so we advance ESI past "echo " (5 chars)
    add esi, 5 ; Skip "e", "c", "h", "o", " "
    
    ; Now ESI points to the start of the argument to echo.
    ; Print the rest of the string (the argument to echo)
    call print_string_rekanto
    mov esi, newline_char_rekanto ; Add a newline after the echoed text
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_echo_no_arg_rekanto:
    ; User typed "echo" exactly, with no arguments.
    mov esi, newline_char_rekanto ; Just print a blank line.
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_ver_rekanto:
    mov esi, ver_msg_line1
    call print_string_rekanto
    mov esi, ver_msg_line2
    call print_string_rekanto
    mov esi, ver_msg_line3
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_shutdown_rekanto:
    mov esi, shutdown_msg_rekanto
    call print_string_rekanto
    cli                 ; Disable interrupts
    hlt                 ; Halt the CPU
    jmp $               ; Just in case, loop if HLT is ignored (it shouldn't be)


; --- Subroutines (used by rekanto.asm) ---

; update_cursor_pm: Updates the hardware cursor position
; based on current_cursor_pos_x and current_cursor_pos_y
update_cursor_pm:
    pushad
    mov edx, [current_cursor_pos_y]
    mov eax, 80
    mul edx
    add eax, [current_cursor_pos_x] ; EAX = position (row * 80 + col)

    ; Send position to CRT controller
    mov dx, 0x3D4 ; CRT Controller Command Register
    mov al, 0x0E  ; Cursor Location High Register
    out dx, al
    inc dx        ; CRT Controller Data Register (0x3D5)
    mov al, ah    ; High byte of position
    out dx, al

    mov dx, 0x3D4
    mov al, 0x0F  ; Cursor Location Low Register
    out dx, al
    inc dx
    mov al, ah    ; Low byte of position
    out dx, al
    popad
    ret


; clear_screen_rekanto: Clears the entire screen
; Uses direct video memory access and updates cursor position
clear_screen_rekanto:
    pushad
    mov edi, VGA_TEXT_MODE_ADDR
    mov ecx, 80 * 25 ; Total characters on screen
    mov al, ' '      ; Character to fill with
    mov ah, DEFAULT_CHAR_ATTR ; Attribute
    mov edx, eax     ; edx = char+attr word
    shl edx, 8
    or edx, eax      ; edx = 0x07200720 (space with attribute, repeated twice)

    ; Fill dwords (4 bytes at a time)
    .loop:
        stosd ; Store EAX (char+attr) into [EDI], increment EDI by 4
        stosd ; Store EAX (char+attr) into [EDI], increment EDI by 4
        dec ecx ; Decrement character count by 2
        dec ecx
        test ecx, ecx
        jnz .loop

    ; Reset cursor position
    mov dword [current_cursor_pos_x], 0
    mov dword [current_cursor_pos_y], 0
    call update_cursor_pm
    popad
    ret

; scroll_screen_up_rekanto: Scrolls the screen up by one line
scroll_screen_up_rekanto:
    pushad
    mov esi, VGA_TEXT_MODE_ADDR + (80 * 2) ; Source: Second row
    mov edi, VGA_TEXT_MODE_ADDR         ; Destination: First row
    mov ecx, 80 * 24 * 2 / 4    ; Copy 24 rows, 2 bytes/char, in dwords
    rep movsd                   ; Move 24 rows up

    ; Clear the last row
    mov edi, VGA_TEXT_MODE_ADDR + (80 * 24 * 2) ; Start of last row
    mov ecx, 80                 ; 80 characters to clear
    mov al, ' '                 ; Space character
    mov ah, DEFAULT_CHAR_ATTR   ; Attribute
    .clear_last_row_loop:
        stosw                   ; Store character and attribute
        loop .clear_last_row_loop

    popad
    ret

; print_string_rekanto: Prints a null-terminated string at ESI to VGA text mode
print_string_rekanto:
    pushad
    
    ; Calculate current video memory pointer from cursor position
    mov eax, [current_cursor_pos_y]
    mov ebx, 80
    mul ebx                     ; EAX = row * 80
    add eax, [current_cursor_pos_x] ; EAX = total chars offset
    shl eax, 1                  ; EAX = byte offset (char * 2 bytes/char)
    add eax, VGA_TEXT_MODE_ADDR ; EAX = actual video memory address
    mov edi, eax                ; EDI = destination in VRAM

.loop:
    lodsb                       ; Load byte from [ESI] into AL, increment ESI
    cmp al, 0                   ; Check for null terminator
    je .done

    cmp al, 0x0D                ; Check for Carriage Return (CR)
    je .handle_cr

    cmp al, 0x0A                ; Check for Line Feed (LF)
    je .handle_lf

    ; Handle regular character
    mov ah, DEFAULT_CHAR_ATTR   ; Character attribute (white on black)
    stosw                       ; Store AL (char) and AH (attr) as a word into [EDI], increment EDI by 2
    
    inc dword [current_cursor_pos_x] ; Increment X cursor
    cmp dword [current_cursor_pos_x], 80 ; Check if end of line
    jl .continue_loop           ; Not end of line, continue

    ; If end of line, implicitly move to next line
    jmp .handle_lf_continue

.handle_cr:
    ; Reset X cursor to 0
    mov dword [current_cursor_pos_x], 0
    ; Recalculate EDI to start of line based on new X
    mov eax, [current_cursor_pos_y]
    mov ebx, 80
    mul ebx
    add eax, [current_cursor_pos_x]
    shl eax, 1
    add eax, VGA_TEXT_MODE_ADDR
    mov edi, eax
    jmp .continue_loop

.handle_lf:
    ; Increment Y cursor
    inc dword [current_cursor_pos_y]
    ; Reset X cursor to 0
    mov dword [current_cursor_pos_x], 0

.handle_lf_continue:
    ; Check for scrolling if we hit the end of the screen
    cmp dword [current_cursor_pos_y], 25 ; Beyond last row?
    jl .recalc_edi ; No scrolling needed, continue

    ; Scroll screen up by one line
    call scroll_screen_up_rekanto
    mov dword [current_cursor_pos_y], 24 ; Cursor is now on the last line (index 24)
    ; EDI should already be set to start of last line by scroll_screen_up_rekanto if we reset it here

.recalc_edi:
    ; Recalculate EDI based on new cursor position
    mov eax, [current_cursor_pos_y]
    mov ebx, 80
    mul ebx
    add eax, [current_cursor_pos_x]
    shl eax, 1
    add eax, VGA_TEXT_MODE_ADDR
    mov edi, eax

.continue_loop:
    call update_cursor_pm ; Update hardware cursor
    jmp .loop

.done:
    call update_cursor_pm ; Ensure cursor is updated after string
    popad
    ret

; read_input_line_rekanto: Reads characters until Enter (0x1C scan code) is pressed or buffer is full.
; Stores input in input_buffer_rekanto (DI). Updates ECX with length.
read_input_line_rekanto:
    pushad
    mov edi, input_buffer_rekanto ; EDI points to buffer start
    xor ecx, ecx                  ; ECX = 0 (current length of input)

.read_char_loop:
    ; Poll keyboard status port 0x64 (status register) until bit 0 (output buffer full) is set
    .wait_for_key:
        in al, 0x64
        test al, 0x01 ; Test bit 0
        jz .wait_for_key

    ; Read scan code from keyboard data port 0x60
    in al, 0x60

    ; Check if it's a key press (bit 7 clear for press, set for release)
    test al, 0x80
    jnz .read_char_loop ; If bit 7 is set, it's a key release, ignore

    ; Store scan code in AH for now, AL for character (will map later)
    mov ah, al

    ; --- Basic Scan Code to ASCII Mapping (Limited for simplicity) ---
    ; This is a very basic mapping. A full keyboard driver would be more complex.
    ; Only handling common keys (a-z, 0-9, space, enter, backspace)
    xor al, al ; Clear AL for character

    cmp ah, 0x1C ; Enter key (scan code 0x1C)
    je .done_reading

    cmp ah, 0x0E ; Backspace key (scan code 0x0E)
    je .handle_backspace

    ; Numeric keys 0-9
    cmp ah, 0x0B ; 0
    je .map_0
    cmp ah, 0x02 ; 1
    je .map_1
    cmp ah, 0x03 ; 2
    je .map_2
    cmp ah, 0x04 ; 3
    je .map_3
    cmp ah, 0x05 ; 4
    je .map_4
    cmp ah, 0x06 ; 5
    je .map_5
    cmp ah, 0x07 ; 6
    je .map_6
    cmp ah, 0x08 ; 7
    je .map_7
    cmp ah, 0x09 ; 8
    je .map_8
    cmp ah, 0x0A ; 9
    je .map_9

    ; Alphabet keys (simple mapping, assuming lowercase for now)
    cmp ah, 0x1E ; A
    je .map_a
    cmp ah, 0x30 ; B
    je .map_b
    cmp ah, 0x2E ; C
    je .map_c
    cmp ah, 0x20 ; D
    je .map_d
    cmp ah, 0x12 ; E
    je .map_e
    cmp ah, 0x21 ; F
    je .map_f
    cmp ah, 0x22 ; G
    je .map_g
    cmp ah, 0x23 ; H
    je .map_h
    cmp ah, 0x17 ; I
    je .map_i
    cmp ah, 0x24 ; J
    je .map_j
    cmp ah, 0x25 ; K
    je .map_k
    cmp ah, 0x26 ; L
    je .map_l
    cmp ah, 0x32 ; M
    je .map_m
    cmp ah, 0x31 ; N
    je .map_n
    cmp ah, 0x18 ; O
    je .map_o
    cmp ah, 0x19 ; P
    je .map_p
    cmp ah, 0x10 ; Q
    je .map_q
    cmp ah, 0x13 ; R
    je .map_r
    cmp ah, 0x1F ; S
    je .map_s
    cmp ah, 0x14 ; T
    je .map_t
    cmp ah, 0x16 ; U
    je .map_u
    cmp ah, 0x2F ; V
    je .map_v
    cmp ah, 0x11 ; W
    je .map_w
    cmp ah, 0x2D ; X
    je .map_x
    cmp ah, 0x15 ; Y
    je .map_y
    cmp ah, 0x2C ; Z
    je .map_z

    cmp ah, 0x39 ; Spacebar
    je .map_space

    jmp .read_char_loop ; If not a mapped key, ignore it

    .map_0: mov al, '0' ; Continue with rest of keyboard mappings
        jmp .store_char
    .map_1: mov al, '1'
        jmp .store_char
    .map_2: mov al, '2'
        jmp .store_char
    .map_3: mov al, '3'
        jmp .store_char
    .map_4: mov al, '4'
        jmp .store_char
    .map_5: mov al, '5'
        jmp .store_char
    .map_6: mov al, '6'
        jmp .store_char
    .map_7: mov al, '7'
        jmp .store_char
    .map_8: mov al, '8'
        jmp .store_char
    .map_9: mov al, '9'
        jmp .store_char
    .map_a: mov al, 'a'
        jmp .store_char
    .map_b: mov al, 'b'
        jmp .store_char
    .map_c: mov al, 'c'
        jmp .store_char
    .map_d: mov al, 'd'
        jmp .store_char
    .map_e: mov al, 'e'
        jmp .store_char
    .map_f: mov al, 'f'
        jmp .store_char
    .map_g: mov al, 'g'
        jmp .store_char
    .map_h: mov al, 'h'
        jmp .store_char
    .map_i: mov al, 'i'
        jmp .store_char
    .map_j: mov al, 'j'
        jmp .store_char
    .map_k: mov al, 'k'
        jmp .store_char
    .map_l: mov al, 'l'
        jmp .store_char
    .map_m: mov al, 'm'
        jmp .store_char
    .map_n: mov al, 'n'
        jmp .store_char
    .map_o: mov al, 'o'
        jmp .store_char
    .map_p: mov al, 'p'
        jmp .store_char
    .map_q: mov al, 'q'
        jmp .store_char
    .map_r: mov al, 'r'
        jmp .store_char
    .map_s: mov al, 's'
        jmp .store_char
    .map_t: mov al, 't'
        jmp .store_char
    .map_u: mov al, 'u'
        jmp .store_char
    .map_v: mov al, 'v'
        jmp .store_char
    .map_w: mov al, 'w'
        jmp .store_char
    .map_x: mov al, 'x'
        jmp .store_char
    .map_y: mov al, 'y'
        jmp .store_char
    .map_z: mov al, 'z'
        jmp .store_char
    .map_space: mov al, ' '
        jmp .store_char

.store_char:
    ; Only process if a valid character was mapped (AL is not 0)
    cmp al, 0
    je .read_char_loop

    ; Check if buffer is full
    cmp ecx, MAX_COMMAND_LEN - 1 ; Leave space for null terminator
    ja .read_char_loop           ; If buffer full, ignore character

    ; Store character in buffer
    stosb                        ; Store AL into [EDI], increment EDI
    inc ecx                      ; Increment length

    ; Echo character to screen
    push esi                     ; Save ESI (used by print_char_rekanto)
    mov esi, edi                 ; Current cursor position for print_char_rekanto
    dec esi                      ; Move back to the character just written
    call print_char_rekanto      ; Print the character
    pop esi                      ; Restore ESI

    jmp .read_char_loop

.handle_backspace:
    cmp ecx, 0                   ; Don't backspace if buffer is empty
    je .read_char_loop

    dec ecx                      ; Decrement length
    dec edi                      ; Move EDI back
    mov byte [edi], 0            ; Clear character in buffer

    ; Erase character from screen: backspace, print space, backspace again
    ; Need to manually adjust cursor for backspace visual effect
    dec dword [current_cursor_pos_x]
    cmp dword [current_cursor_pos_x], 0xFFFFFFFF ; Check for wrap around (e.g., from 0 to -1)
    jne .skip_y_backtrack
    ; If wrapped, it means we were at column 0, move to previous row, last column
    mov dword [current_cursor_pos_x], 79
    dec dword [current_cursor_pos_y]
.skip_y_backtrack:
    call update_cursor_pm

    push esi                     ; Save ESI
    mov esi, char_space          ; Print a space over the erased char
    call print_char_rekanto_no_cursor_update ; Use specialized print function
    pop esi

    dec dword [current_cursor_pos_x] ; Move cursor back again to 'over' the space
    cmp dword [current_cursor_pos_x], 0xFFFFFFFF ; Check for wrap around
    jne .skip_y_backtrack2
    mov dword [current_cursor_pos_x], 79
    dec dword [current_cursor_pos_y]
.skip_y_backtrack2:
    call update_cursor_pm

    jmp .read_char_loop

.done_reading:
    mov byte [edi], 0            ; Null-terminate the input string
    ; Print a newline after user presses Enter, but before prompt
    mov esi, newline_char_rekanto
    call print_string_rekanto
    popad                        ; Restore registers
    ret

; print_char_rekanto: Prints a single character from AL to VGA text mode
; and updates cursor position.
print_char_rekanto:
    pushad
    ; Calculate current video memory pointer from cursor position
    mov eax, [current_cursor_pos_y]
    mov ebx, 80
    mul ebx                     ; EAX = row * 80
    add eax, [current_cursor_pos_x] ; EAX = total chars offset
    shl eax, 1                  ; EAX = byte offset (char * 2 bytes/char)
    add eax, VGA_TEXT_MODE_ADDR ; EAX = actual video memory address
    mov edi, eax                ; EDI = destination in VRAM

    ; Character to print is in AL from calling function
    mov ah, DEFAULT_CHAR_ATTR   ; Character attribute (white on black)
    stosw                       ; Store AL (char) and AH (attr) as a word into [EDI], increment EDI by 2

    inc dword [current_cursor_pos_x] ; Increment X cursor
    cmp dword [current_cursor_pos_x], 80 ; Check if end of line
    jl .no_newline_needed           ; Not end of line, continue

    ; If end of line, move to next line
    mov dword [current_cursor_pos_x], 0
    inc dword [current_cursor_pos_y]

    ; Check for scrolling if we hit the end of the screen
    cmp dword [current_cursor_pos_y], 25 ; Beyond last row?
    jl .no_scroll_needed ; No scrolling needed, continue

    ; Scroll screen up by one line
    call scroll_screen_up_rekanto
    mov dword [current_cursor_pos_y], 24 ; Cursor is now on the last line (index 24)

.no_scroll_needed:
.no_newline_needed:
    call update_cursor_pm ; Update hardware cursor
    popad
    ret

; print_char_rekanto_no_cursor_update: Prints a single char from AL to VGA text mode
; at the current cursor position, but does NOT update cursor position or scroll.
; Used internally by handle_backspace for visual effect.
print_char_rekanto_no_cursor_update:
    pushad
    ; Calculate current video memory pointer from cursor position
    mov eax, [current_cursor_pos_y]
    mov ebx, 80
    mul ebx                     ; EAX = row * 80
    add eax, [current_cursor_pos_x] ; EAX = total chars offset
    shl eax, 1                  ; EAX = byte offset (char * 2 bytes/char)
    add eax, VGA_TEXT_MODE_ADDR ; EAX = actual video memory address
    mov edi, eax                ; EDI = destination in VRAM

    ; Character to print is in AL from calling function
    mov ah, DEFAULT_CHAR_ATTR   ; Character attribute (white on black)
    stosw                       ; Store AL (char) and AH (attr) as a word into [EDI], increment EDI by 2

    popad
    ret

; compare_strings_rekanto: Compares null-terminated string at ESI with string at EBX.
; Sets Carry Flag (CF) if strings are identical, clears CF otherwise.
; Preserves ESI, EBX, ECX, EDI.
compare_strings_rekanto:
    pushad
    
    mov edi, esi             ; Use EDI to iterate through ESI (input)
    mov esi, ebx             ; ESI will iterate through EBX (command)
    
.loop_compare:
    lodsb                    ; Load byte from [ESI] (command char) into AL, ESI++
    mov bl, byte [edi]       ; Load byte from [EDI] (input char) into BL
    
    cmp al, bl               ; Compare characters
    jne .no_match            ; If not equal, strings don't match

    cmp al, 0                ; Check if we reached null terminator for command string
    je .match                ; If command string ended, and so did input, it's a match

    inc edi                  ; Move to next input char
    jmp .loop_compare        ; Continue comparison

.no_match:
    clc                      ; Clear Carry Flag (no match)
    jmp .done_compare

.match:
    cmp bl, 0                ; Ensure input string also ended at the same point
    jne .no_match            ; If input string is longer, it's not a match

    stc                      ; Set Carry Flag (match)

.done_compare:
    popad
    ret

; compare_prefix_rekanto: Compares null-terminated string at EBX (prefix) with start of string at ESI (input).
; Sets Carry Flag (CF) if EBX matches the start of ESI.
; Preserves ESI, EBX, ECX, EDI.
; Input: ESI = pointer to full input string, EBX = pointer to prefix string (e.g., "echo ")
compare_prefix_rekanto:
    pushad
    
    mov edi, esi             ; EDI iterates through input string
    mov esi, ebx             ; ESI iterates through prefix string (e.g., "echo ")
    
.loop_compare_prefix:
    lodsb                    ; Load byte from [ESI] (prefix char) into AL, ESI++
    cmp al, 0                ; Check if we reached null terminator for prefix string
    je .match_prefix         ; If prefix string ended, it's a match

    mov bl, byte [edi]       ; Load byte from [EDI] (input char) into BL
    cmp al, bl               ; Compare characters
    jne .no_match_prefix     ; If not equal, no match

    inc edi                  ; Move to next input char in input_buffer
    jmp .loop_compare_prefix ; Continue comparison

.no_match_prefix:
    clc                      ; Clear Carry Flag (no match)
    jmp .done_compare_prefix

.match_prefix:
    stc                      ; Set Carry Flag (match)

.done_compare_prefix:
    popad
    ret

; --- Data Messages (for rekanto.asm) ---
welcome_cli_msg     db 'Welcome!', 0x0D, 0x0A, 0

newline_char_rekanto db 0x0D, 0x0A, 0 ; Separate newline for this module

prompt_msg_rekanto          db '> ', 0
unknown_cmd_msg_rekanto     db 'Command is not recognized, type "help" for a list of available commands.', 0x0D, 0x0A, 0

; Command strings (must be null-terminated)
help_cmd_str_rekanto        db 'help', 0
clear_cmd_str_rekanto       db 'clear', 0
echo_cmd_str_rekanto        db 'echo', 0        ; For exact "echo" command
echo_cmd_prefix_rekanto     db 'echo ', 0       ; For "echo " followed by arguments
ver_cmd_str_rekanto         db 'ver', 0         ; New 'ver' command string
shutdown_cmd_str_rekanto    db 'shutdown', 0

; Help message
help_msg_rekanto            db 'Available commands:', 0x0D, 0x0A
                            db '  help         - Display this help message', 0x0D, 0x0A
                            db '  clear        - Clear the screen', 0x0D, 0x0A
                            db '  echo <text>  - Prints text (e.g., echo Hello World)', 0x0D, 0x0A
                            db '  ver          - Display version information', 0x0D, 0x0A
                            db '  shutdown     - Halts the system', 0x0D, 0x0A
                            db '  (More commands coming soon!)', 0x0D, 0x0A, 0

; Version messages for 'ver' command
ver_msg_line1       db 'Horibyte Arctic32 Server Version 0.1.5 - PreAlpha Developer Release', 0x0D, 0x0A, 0
ver_msg_line2       db 'For testing purposes only.', 0x0D, 0x0A, 0
ver_msg_line3       db 'Copyright (c) 2025 Horibyte. Source code licensed under GNU GPL 3.0', 0x0D, 0x0A, 0

shutdown_msg_rekanto        db 'Operation not supported. System halted.', 0x0D, 0x0A, 0

char_space          db ' ', 0 ; Single space character for backspace visual

; --- Buffers ---
input_buffer_rekanto resb MAX_COMMAND_LEN ; Reserve space for user input

; --- Padding ---
; Optional: If you need to pad this file to a specific size, e.g., 4KB
; times (0x1000 - ($ - $$)) db 0
