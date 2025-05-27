; rekanto.asm
; Horibyte Arctic ReKanto Kernel
; Copyright (c) 2025 Horibyte

[org 0x0000]    ; This code will be loaded at 0x2000:0x0000 (physical 0x20000)
                ; so its internal addresses are relative to 0x2000.
bits 16         ; Still in 16-bit Real Mode

; --- CONSTANTS ---
MAX_COMMAND_LEN equ 64  ; Maximum length of command user can type

; --- ENTRY POINT OF REKANTO.ASM ---
start_rekanto:
    ; Set up segment registers for rekanto.asm (important!)
    ; CS will be 0x2000 from the JMP in osload.asm
    mov ax, cs      ; Use current CS (0x2000) for data segment
    mov ds, ax      ; Set DS to 0x2000 so data (messages, buffers) are accessible
    mov es, ax      ; Set ES to 0x2000 if needed for string operations

    ; Stack setup for the kernel.
    ; We can continue using 0x0000:0x7FF0 or move it if we need that area.
    ; For now, it's fine. If you later implement memory management, you'd change this.
    xor ax, ax
    mov ss, ax
    mov sp, 0x7FF0

    ; --- Initial CLI message (after being loaded) ---
    mov si, welcome_cli_msg
    call print_string_rekanto
    mov si, newline_char_rekanto ; Blank line after welcome
    call print_string_rekanto

    ; --- Main CLI Loop ---
cli_loop_rekanto:
    mov si, prompt_msg_rekanto  ; Display the prompt
    call print_string_rekanto

    ; Read command from user
    mov di, input_buffer_rekanto ; Store input starting here
    xor cx, cx                   ; CX = 0 (current input length)
    call read_input_line_rekanto ; Read a line of input

    ; A blank line after input for better readability
    mov si, newline_char_rekanto
    call print_string_rekanto

    ; --- Process Command ---
    ; Point SI to the user's input buffer for comparisons
    mov si, input_buffer_rekanto

    ; Compare full string for exact matches (help, clear, shutdown)
    mov bx, help_cmd_str_rekanto
    call compare_strings_rekanto
    jc .is_help_rekanto         ; If CF is set, strings match
    
    mov bx, clear_cmd_str_rekanto
    call compare_strings_rekanto
    jc .is_clear_rekanto

    mov bx, shutdown_cmd_str_rekanto
    call compare_strings_rekanto
    jc .is_shutdown_rekanto

    ; --- Handle "echo" command specifically ---
    ; Check if input starts with "echo "
    mov bx, echo_cmd_prefix_rekanto ; Points to "echo "
    call compare_prefix_rekanto     ; New function to check prefix match
    jc .is_echo_cmd_rekanto         ; If CF is set, it matches "echo "

    ; Handle "echo" command with no arguments ("echo" followed by Enter)
    mov bx, echo_cmd_str_rekanto    ; Points to "echo" (no trailing space)
    call compare_strings_rekanto    ; Check for exact "echo" command
    jc .is_echo_no_arg_rekanto

    ; If command not recognized
    mov si, unknown_cmd_msg_rekanto
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_help_rekanto:
    mov si, help_msg_rekanto
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_clear_rekanto:
    call clear_screen_rekanto
    jmp cli_loop_rekanto

.is_echo_cmd_rekanto:
    ; SI is already pointing to input_buffer_rekanto from above
    ; It means input starts with "echo ", so we advance SI past "echo " (5 chars)
    add si, 5 ; Skip "e", "c", "h", "o", " "
    
    ; Now SI points to the start of the argument to echo.
    ; Print the rest of the string (the argument to echo)
    call print_string_rekanto
    mov si, newline_char_rekanto ; Add a newline after the echoed text
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_echo_no_arg_rekanto:
    ; User typed "echo" exactly, with no arguments.
    mov si, newline_char_rekanto ; Just print a blank line.
    call print_string_rekanto
    jmp cli_loop_rekanto

.is_shutdown_rekanto:
    mov si, shutdown_msg_rekanto
    call print_string_rekanto
    cli                 ; Disable interrupts
    hlt                 ; Halt the CPU
    jmp $               ; Just in case, loop if HLT is ignored (it shouldn't be)


; --- Subroutines (used by rekanto.asm) ---

; clear_screen_rekanto: Clears the entire screen
clear_screen_rekanto:
    pusha           ; Save all general purpose registers
    mov ax, 0x0600  ; AH=06h (scroll window up), AL=00h (clear window)
    mov bh, 0x07    ; BH=07h (attribute: white on black)
    xor cx, cx      ; CH=0, CL=0 (upper-left corner row 0, col 0)
    mov dx, 0x184f  ; DH=24, DL=79 (lower-right corner row 24, col 79)
    int 0x10        ; Call BIOS video services
    popa            ; Restore registers
    ret

; print_string_rekanto: Prints a null-terminated string at DS:SI
print_string_rekanto:
    pusha           ; Save registers used by this function
    mov ah, 0x0e    ; BIOS teletype function (display character, advance cursor)
.loop:
    lodsb           ; Load byte from DS:SI into AL, increment SI
    or al, al       ; Check if AL is zero (end of string)
    jz .done        ; If zero, jump to done
    int 0x10        ; Otherwise, print the character
    jmp .loop       ; Loop back
.done:
    popa            ; Restore registers
    ret             ; Return from function

; read_input_line_rekanto: Reads characters until Enter (0x0D) is pressed or buffer is full.
; Stores input in input_buffer_rekanto (DS:DI). Updates CX with length.
read_input_line_rekanto:
    pusha           ; Save registers
    mov di, input_buffer_rekanto ; DI points to buffer start
    xor cx, cx           ; CX = 0 (current length of input)
.read_char_loop:
    mov ah, 0x00         ; BIOS get keyboard character (with wait)
    int 0x16             ; AL = character, AH = scan code

    cmp al, 0x0D         ; Check for Enter key (CR)
    je .done_reading     ; If Enter, finish input

    cmp al, 0x08         ; Check for Backspace
    je .handle_backspace

    ; Only process printable ASCII characters
    cmp al, 0x20         ; ASCII space (lowest printable)
    jb .read_char_loop   ; If below space, not printable (e.g., control char)
    cmp al, 0x7E         ; ASCII tilde (highest printable)
    ja .read_char_loop   ; If above tilde, not printable

    ; Check if buffer is full
    cmp cx, MAX_COMMAND_LEN - 1 ; Leave space for null terminator
    ja .read_char_loop   ; If buffer full, ignore character

    ; Store character in buffer and echo it
    stosb                ; Store AL into DS:DI, increment DI
    inc cx               ; Increment length
    mov ah, 0x0e         ; Echo character to screen
    int 0x10
    jmp .read_char_loop

.handle_backspace:
    cmp cx, 0            ; Don't backspace if buffer is empty
    je .read_char_loop

    dec cx               ; Decrement length
    dec di               ; Move DI back
    mov byte [di], 0     ; Clear character in buffer (optional, but good practice)

    ; Erase character from screen: backspace, print space, backspace again
    mov ah, 0x0e
    mov al, 0x08         ; Backspace
    int 0x10
    mov al, ' '          ; Print a space
    int 0x10
    mov al, 0x08         ; Backspace again
    int 0x10
    jmp .read_char_loop

.done_reading:
    mov byte [di], 0     ; Null-terminate the input string
    ; Print a newline after user presses Enter, but before prompt
    mov si, newline_char_rekanto
    call print_string_rekanto
    popa            ; Restore registers
    ret

; compare_strings_rekanto: Compares null-terminated string at DS:SI with string at DS:BX.
; Sets Carry Flag (CF) if strings are identical, clears CF otherwise.
; Preserves SI, BX, CX, DI.
compare_strings_rekanto:
    push si
    push bx
    push cx
    push di
    
    xor cx, cx             ; Clear CX
    mov di, si             ; Use DI to iterate through SI (input)
    mov si, bx             ; SI will iterate through BX (command)
    
.loop_compare:
    lodsb                  ; Load byte from [DS:SI] (command char) into AL, SI++
    mov bl, byte [di]      ; Load byte from [DS:DI] (input char) into BL
    
    cmp al, bl             ; Compare characters
    jne .no_match          ; If not equal, strings don't match

    cmp al, 0              ; Check if we reached null terminator for command string
    je .match              ; If command string ended, and so did input, it's a match

    inc di                 ; Move to next input char
    jmp .loop_compare      ; Continue comparison

.no_match:
    clc                    ; Clear Carry Flag (no match)
    jmp .done_compare

.match:
    cmp bl, 0              ; Ensure input string also ended at the same point
    jne .no_match          ; If input string is longer, it's not a match

    stc                    ; Set Carry Flag (match)

.done_compare:
    pop di
    pop cx
    pop bx
    pop si
    ret

; compare_prefix_rekanto: Compares null-terminated string at DS:BX (prefix) with start of string at DS:SI (input).
; Sets Carry Flag (CF) if BX matches the start of SI.
; Preserves SI, BX, CX, DI.
; Input: DS:SI = pointer to full input string, DS:BX = pointer to prefix string (e.g., "echo ")
compare_prefix_rekanto:
    push si
    push bx
    push cx
    push di
    
    mov di, si             ; DI iterates through input string
    mov si, bx             ; SI iterates through prefix string (e.g., "echo ")
    
.loop_compare_prefix:
    lodsb                  ; Load byte from [DS:SI] (prefix char) into AL, SI++
    cmp al, 0              ; Check if we reached null terminator for prefix string
    je .match_prefix       ; If prefix string ended, it's a match

    mov bl, byte [di]      ; Load byte from [DS:DI] (input char) into BL
    cmp al, bl             ; Compare characters
    jne .no_match_prefix   ; If not equal, no match

    inc di                 ; Move to next input char in input_buffer
    jmp .loop_compare_prefix ; Continue comparison

.no_match_prefix:
    clc                    ; Clear Carry Flag (no match)
    jmp .done_compare_prefix

.match_prefix:
    stc                    ; Set Carry Flag (match)

.done_compare_prefix:
    pop di
    pop cx
    pop bx
    pop si
    ret

; --- Data Messages (for rekanto.asm) ---
welcome_cli_msg     db 'Welcome!', 0x0d, 0x0a, 0

newline_char_rekanto db 0x0d, 0x0a, 0 ; Separate newline for this module

prompt_msg_rekanto          db '> ', 0
unknown_cmd_msg_rekanto     db 'Command is not recognized, type "help" for a list of available commands.', 0x0d, 0x0a, 0

; Command strings (must be null-terminated)
help_cmd_str_rekanto        db 'help', 0
clear_cmd_str_rekanto       db 'clear', 0
echo_cmd_str_rekanto        db 'echo', 0            ; For exact "echo" command
echo_cmd_prefix_rekanto     db 'echo ', 0           ; For "echo " followed by arguments
shutdown_cmd_str_rekanto    db 'shutdown', 0

; Help message
help_msg_rekanto            db 'Available commands:', 0x0d, 0x0a
                            db '  help       - Display this help message', 0x0d, 0x0a
                            db '  clear      - Clear the screen', 0x0d, 0x0a
                            db '  echo <text> - Prints text (e.g., echo Hello World)', 0x0d, 0x0a
                            db '  shutdown   - Halts the system', 0x0d, 0x0a
                            db '  (More commands coming soon!)', 0x0d, 0x0a, 0

shutdown_msg_rekanto        db 'Operation not supported. System halted.', 0x0d, 0x0a, 0

; --- Buffers ---
input_buffer_rekanto resb MAX_COMMAND_LEN ; Reserve space for user input

; --- Padding ---
times 512*8 - ($ - $$) db 0