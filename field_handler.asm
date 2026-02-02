section .bss
section .data
section .text

global configure_field, free_fields
; Project internal functions and variables
extern FIELDS_ARRAY, FIELD_WIDTH, FIELD_AREA
; glibc functions


; configure the field with a fixed pattern
; maybe I will add support for input of a pattern of cells later on...
; (-)[-]
configure_field:
    ; Prologe - actually we wouldn't need it here but to keep everything in order...
    push    rbp
    mov     rbp, rsp
    and     rsp, -16
    
    ; Special Cell Configuration:
    ;       OO             (24,25)(25,25)
    ;      OO       (23,26)(24,26)
    ;       O              (24,27)
    ; For the starting y-coordinate 25, we instead take the field area / 2
    ; All the following coordinates are for illustration only and do not match with the end-result!
    ; y-coordinate calculates with y-coordinate * row-width:
    ; Then add the x-coordinate to the result --> out comes a 1d coordinate representation of a 2d coordinate
    mov     rdi, [FIELDS_ARRAY] ; move pointer to game field into destination register

    ; move into rax the starting point in the coordination field
    mov     rax, [FIELD_AREA]   ; move field area into rax --> divident
    mov     rcx, 0x2            ; move 2 into rcx --> divisor
    xor     rdx, rdx            ; clear rdx for div, cause divident is RDX:RAX 
    div     rcx                 ; rax / rcx (2)

    ; create the first two cells
    add     rax, 25             ; create the first coodinate (25,25)
    mov     byte [rdi+rax], 0x1 ; put a living cell at that coordinate of the game field
    mov     byte [rdi+rax-0x1], 0x1  ; also put a living cell at the next coordinate (24,25) of the game field

    ; move one row up and create next two cells
    add     rax, [FIELD_WIDTH]  ; add another row to rax --> we are now at (24,26)
    mov     byte [rdi+rax], 0x1 ; put a living cell at that coordinate of the game field
    mov     byte [rdi+rax-0x1], 0x1 ; also put a living cell at the coordinate (23,26) of the game field

    ; move another row up and create last cell
    add     rax, [FIELD_WIDTH]  ; add another row --> we are not at (24,27)
    mov     byte [rdi+rax], 0x1 ; put a living cell there
    ; we are finished with this configuration --> return from this function

    .return:
        ; Epilog
        mov     rsp, rbp
        pop     rbp
        ret


free_fields:
    nop
    ret