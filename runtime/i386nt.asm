;**************************************************************************
;*                                                                        *
;*                                 OCaml                                  *
;*                                                                        *
;*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *
;*                                                                        *
;*   Copyright 1996 Institut National de Recherche en Informatique et     *
;*     en Automatique.                                                    *
;*                                                                        *
;*   All rights reserved.  This file is distributed under the terms of    *
;*   the GNU Lesser General Public License version 2.1, with the          *
;*   special exception on linking described in the file LICENSE.          *
;*                                                                        *
;**************************************************************************

; Asm part of the runtime system, Intel 386 processor, Intel syntax

        .386
        .MODEL FLAT

        EXTERN  _caml_garbage_collection: PROC
        EXTERN  _caml_apply2: PROC
        EXTERN  _caml_apply3: PROC
        EXTERN  _caml_program: PROC
        EXTERN  _caml_array_bound_error: PROC
        EXTERN  _caml_stash_backtrace: PROC
        EXTERN  _Caml_state: DWORD

; Load caml/domain_state.tbl (via domain_state.inc, to remove C-style comments)
        domain_curr_field = 0
DOMAIN_STATE MACRO _type:REQ, name:REQ
        domain_field_caml_&name EQU domain_curr_field
        domain_curr_field = domain_curr_field + 1
        ; Returning a value turns DOMAIN_STATE into a macro function, which
        ; causes the bracketed parameters to be both required and correctly
        ; parsed. Returning an empty string allows this to be used as though
        ; it were a macro procedure.
        EXITM <>
ENDM

INCLUDE domain_state.inc

; Caml_state(field[, reg]) expands to the address of field in Caml_state.
; Caml_state is assumed to be in ebx if reg is not specified.
Caml_state MACRO field:REQ, reg:=<ebx>
        EXITM @CatStr(<[>, reg, <+>, %(domain_field_caml_&field), <*8]>)
ENDM

        .CODE

        PUBLIC  _caml_system__code_begin
_caml_system__code_begin:
        ret  ; just one instruction, so that debuggers don't display
             ; caml_system__code_begin instead of caml_call_gc
; Allocation

        PUBLIC  _caml_call_gc
        PUBLIC  _caml_alloc1
        PUBLIC  _caml_alloc2
        PUBLIC  _caml_alloc3
        PUBLIC  _caml_allocN

_caml_call_gc:
    ; Record lowest stack address and return address
        mov     ebx, _Caml_state
        mov     eax, [esp]
        mov     Caml_state(last_return_address), eax
        lea     eax, [esp+4]
        mov     Caml_state(bottom_of_stack), eax
    ; Save all regs used by the code generator
        push    ebp
        push    edi
        push    esi
        push    edx
        push    ecx
        push    ebx
        push    eax
        mov     Caml_state(gc_regs), esp
    ; Call the garbage collector
        call    _caml_garbage_collection
    ; Restore all regs used by the code generator
        pop     eax
        pop     ebx
        pop     ecx
        pop     edx
        pop     esi
        pop     edi
        pop     ebp
    ; Return to caller. Returns young_ptr in eax
        mov     eax, Caml_state(young_ptr)
        ret

        ALIGN  4
_caml_alloc1:
        mov     ebx, _Caml_state
        mov     eax, Caml_state(young_ptr)
        sub     eax, 8
        mov     Caml_state(young_ptr), eax
        cmp     eax, Caml_state(young_limit)
        jb      _caml_call_gc
        ret

        ALIGN  4
_caml_alloc2:
        mov     ebx, _Caml_state
        mov     eax, Caml_state(young_ptr)
        sub     eax, 12
        mov     Caml_state(young_ptr), eax
        cmp     eax, Caml_state(young_limit)
        jb      _caml_call_gc
        ret

        ALIGN  4
_caml_alloc3:
        mov     ebx, _Caml_state
        mov     eax, Caml_state(young_ptr)
        sub     eax, 16
        mov     Caml_state(young_ptr), eax
        cmp     eax, Caml_state(young_limit)
        jb      _caml_call_gc
        ret

        ALIGN  4
_caml_allocN:
        mov     ebx, _Caml_state
        sub     eax, Caml_state(young_ptr) ; eax = size - young_ptr
        neg     eax                        ; eax = young_ptr - size
        mov     Caml_state(young_ptr), eax
        cmp     eax, Caml_state(young_limit)
        jb      _caml_call_gc
        ret

; Call a C function from OCaml

        PUBLIC  _caml_c_call
        ALIGN  4
_caml_c_call:
    ; Record lowest stack address and return address
    ; ecx and edx are destroyed at C call. Use them as temp.
        mov     ecx, _Caml_state
        mov     edx, [esp]
        mov     Caml_state(last_return_address, ecx), edx
        lea     edx, [esp+4]
        mov     Caml_state(bottom_of_stack, ecx), edx
    ; Call the function (address in %eax)
        jmp     eax

; Start the OCaml program

        PUBLIC  _caml_start_program
        ALIGN  4
_caml_start_program:
    ; Save callee-save registers
        push    ebx
        push    esi
        push    edi
        push    ebp
    ; Initial code pointer is caml_program
        mov     esi, offset _caml_program

; Code shared between caml_start_program and callback*

L106:
        mov     edi, _Caml_state
    ; Build a callback link
        push    Caml_state(gc_regs, edi)
        push    Caml_state(last_return_address, edi)
        push    Caml_state(bottom_of_stack, edi)
    ; Build an exception handler
        push    L108
        push    Caml_state(exception_pointer, edi)
        mov     Caml_state(exception_pointer, edi), esp
    ; Call the OCaml code
        call    esi
L107:
        mov     edi, _Caml_state
    ; Pop the exception handler
        pop     Caml_state(exception_pointer, edi)
        add     esp, 4
L109:
        mov     edi, _Caml_state
    ; Pop the callback link, restoring the global variables
    ; used by caml_c_call
        pop     Caml_state(bottom_of_stack, edi)
        pop     Caml_state(last_return_address, edi)
        pop     Caml_state(gc_regs, edi)
    ; Restore callee-save registers.
        pop     ebp
        pop     edi
        pop     esi
        pop     ebx
    ; Return to caller.
        ret
L108:
    ; Exception handler
    ; Mark the bucket as an exception result and return it
        or      eax, 2
        jmp     L109

; Raise an exception for OCaml

        PUBLIC  _caml_raise_exn
        ALIGN   4
_caml_raise_exn:
        mov     ebx, _Caml_state
        mov     ecx, Caml_state(backtrace_active)
        test    ecx, 1
        jne     L110
        mov     esp, Caml_state(exception_pointer)
        pop     Caml_state(exception_pointer)
        ret
L110:
        mov     esi, eax                           ; Save exception bucket
        mov     edi, Caml_state(exception_pointer) ; SP of handler
        mov     eax, [esp]                         ; PC of raise
        lea     edx, [esp+4]                       ; SP of raise
        push    edi                                ; arg 4: SP of handler
        push    edx                                ; arg 3: SP of raise
        push    eax                                ; arg 2: PC of raise
        push    esi                                ; arg 1: exception bucket
        call    _caml_stash_backtrace
        mov     eax, esi                           ; recover exception bucket
        mov     esp, edi                           ; cut the stack
        pop     Caml_state(exception_pointer)
        ret

; Raise an exception from C

        PUBLIC  _caml_raise_exception
        ALIGN  4
_caml_raise_exception:
        mov     ebx, _Caml_state
        mov     ecx, Caml_state(backtrace_active)
        test    ecx, 1
        jne     L112
        mov     eax, [esp+8]
        mov     esp, Caml_state(exception_pointer)
        pop     Caml_state(exception_pointer)
        ret
L112:
        mov     esi, [esp+8]                       ; Save exception bucket
        push    Caml_state(exception_pointer)      ; arg 4: SP of handler
        push    Caml_state(bottom_of_stack)        ; arg 3: SP of raise
        push    Caml_state(last_return_address)    ; arg 2: PC of raise
        push    esi                                ; arg 1: exception bucket
        call    _caml_stash_backtrace
        mov     eax, esi                           ; recover exception bucket
        mov     esp, Caml_state(exception_pointer) ; cut the stack
        pop     Caml_state(exception_pointer)
        ret

; Callback from C to OCaml

        PUBLIC  _caml_callback_asm
        ALIGN  4
_caml_callback_asm:
    ; Save callee-save registers
        push    ebx
        push    esi
        push    edi
        push    ebp
    ; Initial loading of arguments
        mov     ebx, [esp+24]   ; arg2: closure
        mov     edi, [esp+28]   ; arguments array
        mov     eax, [edi]      ; arg1: argument
        mov     esi, [ebx]      ; code pointer
        jmp     L106

        PUBLIC  _caml_callback2_asm
        ALIGN  4
_caml_callback2_asm:
    ; Save callee-save registers
        push    ebx
        push    esi
        push    edi
        push    ebp
    ; Initial loading of arguments
        mov     ecx, [esp+24]   ; arg3: closure
        mov     edi, [esp+28]   ; arguments array
        mov     eax, [edi]      ; arg1: first argument
        mov     ebx, [edi+4]    ; arg2: second argument
        mov     esi, offset _caml_apply2   ; code pointer
        jmp     L106

        PUBLIC  _caml_callback3_asm
        ALIGN   4
_caml_callback3_asm:
    ; Save callee-save registers
        push    ebx
        push    esi
        push    edi
        push    ebp
    ; Initial loading of arguments
        mov     edx, [esp+24]   ; arg4: closure
        mov     edi, [esp+28]   ; arguments array
        mov     eax, [edi]      ; arg1: first argument
        mov     ebx, [edi+4]    ; arg2: second argument
        mov     ecx, [edi+8]    ; arg3: third argument
        mov     esi, offset _caml_apply3   ; code pointer
        jmp     L106

        PUBLIC  _caml_ml_array_bound_error
        ALIGN   4
_caml_ml_array_bound_error:
    ; Empty the floating-point stack
        ffree   st(0)
        ffree   st(1)
        ffree   st(2)
        ffree   st(3)
        ffree   st(4)
        ffree   st(5)
        ffree   st(6)
        ffree   st(7)
    ; Branch to caml_array_bound_error
        mov     eax, offset _caml_array_bound_error
        jmp     _caml_c_call

        PUBLIC _caml_system__code_end
_caml_system__code_end:

        .DATA
        PUBLIC  _caml_system__frametable
_caml_system__frametable LABEL DWORD
        DWORD   1               ; one descriptor
        DWORD   L107            ; return address into callback
        WORD    -1              ; negative frame size => use callback link
        WORD    0               ; no roots here

        PUBLIC  _caml_extra_params
_caml_extra_params LABEL DWORD
        BYTE    256 DUP (?)

        END
