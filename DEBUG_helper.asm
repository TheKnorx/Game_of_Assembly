; NOTE: This file does not meet code style regulations, commentary regulations or any other regulations
; This file is purely for debugging purposes and therefore not as clean as the other ones

section .bss
section .data
    NEIGHBOUR_TEST: db "Cell at [%d][%d] with %d neighbours", 0
    CELL_STATE: db " --> %c", 10, 0
section .text

; make all debug function global
global print_neighbour, print_new_cell_state


; glibc functions
extern printf, putchar


%macro push_all 0
    pushfq

    push rax
    push rcx
    push rdx
    push rdi

    push r8
    push r9
    push r10
    push r11
%endmacro


%macro pop_all 0
    pop  r11
    pop  r10
    pop  r9
    pop  r8

    pop  rdi
    pop  rdx
    pop  rcx
    pop  rax

    popfq                  ; restore flags last
%endmacro



; function for printing the amount of neighbours
; we expect the neighbours count and cells coordinate in stack
print_neighbour: 
    push    rbp
    mov     rbp, rsp
    push_all

    xor     rax, rax
    mov     rdi, NEIGHBOUR_TEST
    mov     rsi, [rbp+8*2] ; first
    mov     rdx, [rbp+8*3] ; second
    mov     rcx, [rbp+8*4] ; third
    call    printf

    pop_all
    mov     rbp, rsp
    pop     rbp
    ret

; function for printing the next cell state in the future
; we expect a 1 or 0 in stack
print_new_cell_state: 
    push    rbp
    mov     rbp, rsp
    push_all

    xor     rax, rax
    mov     rdi, CELL_STATE
    mov     rsi, [rbp+8*2] ; first
    call    printf

    pop_all
    mov     rbp, rsp
    pop     rbp
    ret