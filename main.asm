BITS 64


section .bss
    ; Reserving a quad-word for each variable out of convenience so that we can use 64-bit everywhere and dont have mix 32- and 64-bit registers together
    ; Dont want to reserve less than that and begin to have a inconsistancy, perhaps writing the wrong values into registers when mixing 32 and 64 bit variables
    FIELD_WIDTH:    resq 0x1    ; reserved 1 quadword for the field width (--> max 2^64 bits ~ 2*10^9GB never gonna need that)
    FIELD_HEIGHT:   resq 0x1    ;               ...             field height            ...
    GENERATIONS:    resq 0x1    ;               ...             generations             ...
    FIELD_AREA:     resq 0x1    ; reserve a qword --> 1 quadword is would be 2^64 bits ~ 2*10^9GB, so wayyyyy too much --> we do a <2^32 mod height*width> for ensuring a guaranteed fit
    FIELDS_ARRAY:   resq 0x2    ; reserve two qwords for two pointers that point to the allocated game fields

section .data
    USAGE_TEXT:     db "Usage: %s <field-width> <field-height> <amount of generations>", 0xA, 0x00
section .text

global main
global FIELD_WIDTH, FIELD_HEIGHT, FIELD_AREA, FIELDS_ARRAY
; project functions that may not return
extern try_ascii_to_int, try_alloc_fields, configure_field, free_fields
; project functions
; extern
; glibc functions:
extern printf


; function for simulating the generations
; ()[]
simulate:
    nop
    ret

; main entry point of program
; we expect the width, the height of the game field as well as the amount of generations to simulate via command line arguments
; (int argc at rdi, char** argv at rsi)[int return-code]
main: 
    ; Prolog
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    ; Additional registers for additional storage:
    push    r12

    .read_cmd_args:     ; check existance of cmd arguments and fill variables accordingly; !we might not get back from this procedure!
        cmp     rdi, 0x4            ; check if all 3 (+1) arguments were passed to the program
        jne     .print_usage        ; if there are cmd args missing, print usage and exit
        ; else continue to parse arguments

        mov     r12, rsi            ; save rsi argument table pointer to r12

        ; get field width: 
        mov     rdi, [r12 + 0x8]    ; ptr to ascii encoded field width number
        call    try_ascii_to_int    ; convert ascii number to actual integer 
        mov     [FIELD_WIDTH], rax  ; move int into field width variable

        ; get field height
        mov     rdi, [r12+0x8*2]    ; ptr to ascii encoded field height number
        call    try_ascii_to_int    ; convert ascii number to actual integer
        mov     [FIELD_HEIGHT], rax ; move int into field height variable

        ; get amount of generations to simulate
        mov     rdi, [r12+0x8*3]    ; ptr to ascii encoded generation number
        call    try_ascii_to_int    ; convert ascii number to actuall integer
        mov     [GENERATIONS], rax  ; move int into generations variable

        ; calculate the field area
        mov     rax, [FIELD_WIDTH]  ; move field width into implicit operand eax for MUL
        mul     qword [FIELD_HEIGHT]; multiply field width with field height
        ;jo      .overflow           ; if OF=1, handle the MUL overflow of edx
        ;jc      .overflow           ; if CF=1, handle the MUL overflow of edx

        ;.normal: 
        ;    mov     [FIELD_AREA], rax       ; mov result of MUL into field area variable
        ;    jmp     .init_field             ; jump out of the cmd parse procedure and into the next one
        ;.overflow:  ; the field width and height were to big for a 32 bit integer, so we do a 2^32 mod width*height
        ;    mov     [FIELD_AREA], rax       ; we do this by just writing the upper/left bits of the result into the field area variable
        ;    ; fall through to next procedure
        mov     [FIELD_AREA], rax       ; move result of MUL into field are variable
        ; fall through to next procedure

    .init_field:  ; init the game field; !we might not get back from this procedure!
        call    try_alloc_fields    ; allocate the two game fields
        call    configure_field     ; now we fill the field with some predefined values

    call    simulate        ; simulate the generations

    .cleanup:  ; end the program by cleaning up
        ; freeing the allocated fields
        call    free_fields
        jmp     .return

    .print_usage:
        ; int printf(const char *restrict format, ...);
        xor     rax, rax            ; clear rax for std*-glibc function
        mov     rdi, USAGE_TEXT     ; const char* to format string
        mov     rsi, [rsi]          ; const char* to first format parameter
        call    printf
        ; fall through to .return procedure

    .return:  ; pop any pushed registers & do the epilog
        ;  pop pushed registers
        pop     r12
        ; set exit code to 0
        xor     rax, rax
        ; Epilog
        mov     rsp, rbp
        pop     rbp
        ret
