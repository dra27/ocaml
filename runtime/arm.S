/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                 Benedikt Meurer, University of Siegen                  */
/*                                                                        */
/*   Copyright 1998 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*   Copyright 2012 Benedikt Meurer.                                      */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Asm part of the runtime system, ARM processor */
/* Must be preprocessed by cpp */

#include "caml/m.h"

        .syntax unified
        .text
#if defined(SYS_linux_eabihf) && defined(MODEL_armv6)
        .arch   armv6
        .fpu    vfpv2
        .arm

    /* Compatibility macros */
        .macro  cbz reg, lbl
        cmp     \reg, #0
        beq     \lbl
        .endm
#elif defined(SYS_linux_eabihf)
        .arch   armv7-a
        .fpu    vfpv3-d16
        .thumb
#elif defined(SYS_linux_eabi)
        .arch   armv4t
        .arm

    /* Compatibility macros */
        .macro  blx reg
        mov     lr, pc
        bx      \reg
        .endm
        .macro  cbz reg, lbl
        cmp     \reg, #0
        beq     \lbl
        .endm
#elif defined(SYS_netbsd)

  #if defined(MODEL_armv6)
        .arch   armv6
        .fpu    vfpv2
        .arm

    /* Compatibility macros */
        .macro  cbz reg, lbl
        cmp     \reg, #0
        beq     \lbl
        .endm
  #elif defined(MODEL_armv7)
        .arch   armv7-a
        .fpu    vfpv3-d16
        .thumb
  #else
    #error "Only NetBSD eabihf supported"
  #endif

#elif defined(SYS_freebsd)
        .arch   armv6
        .arm

    /* Compatibility macros */
        .macro  cbz reg, lbl
        cmp     \reg, #0
        beq     \lbl
        .endm
#endif

trap_ptr          .req    r8
alloc_ptr         .req    r10
domain_state_ptr  .req    r11
stack_arg_begin   .req    r4
stack_arg_end     .req    r5

/* Support for CFI directives */

#if defined(ASM_CFI_SUPPORTED)
#define CFI_STARTPROC .cfi_startproc
#define CFI_ENDPROC .cfi_endproc
#define CFI_ADJUST(n) .cfi_adjust_cfa_offset n
#define CFI_REGISTER(r1,r2) .cfi_register r1,r2
#define CFI_OFFSET(r,n) .cfi_offset r,n
#else
#define CFI_STARTPROC
#define CFI_ENDPROC
#define CFI_ADJUST(n)
#define CFI_REGISTER(r1,r2)
#define CFI_OFFSET(r,n)
#endif

#if defined(FUNCTION_SECTIONS)
#define TEXT_SECTION(name) .section .text.caml.##name,"ax",%progbits
#else
#define TEXT_SECTION(name)
#endif

#define FUNCTION(name) \
        TEXT_SECTION(name); \
        .align 2; \
        .globl name; \
        .type name, %function; \
name:

#if defined(FUNCTION_SECTIONS)
        TEXT_SECTION(caml_hot.code_begin)
        .globl  caml_hot.code_begin
caml_hot.code_begin:

        TEXT_SECTION(caml_hot.code_end)
        .globl  caml_hot.code_end
caml_hot.code_end:
#endif

        .set    domain_curr_field, 0
#define DOMAIN_STATE(c_type, name) \
        .equ    domain_field_caml_##name, domain_curr_field ; \
        .set    domain_curr_field, domain_curr_field + 1
#include "../runtime/caml/domain_state.tbl"
#undef DOMAIN_STATE

#define Caml_state(var) [domain_state_ptr, 8*domain_field_caml_##var]

/* Stack switching operations */

/* struct stack_info */
/* XXX */

/* struct c_stack_link */
/* XXX */

/* struct stack_handler */
/* XXX */

/* Switch from OCaml to C stack. Clobbers r12. */
.macro SWITCH_OCAML_TO_C
    /* Fill in Caml_state->current_stack->sp */
        ldr     r12, Caml_state(current_stack)
        str     sp, Stack_sp(r12)
    /* Switch to C stack */
        ldr     sp, Caml_state(c_stack)
    /* Fill in Caml_state->c_stack */
        str     r12, Cstack_stack(sp)
        ldr     r12, Stack_sp(r12)
        str     r12, Cstack_sp(sp)
.endm

/* Switch from C to OCaml stack. */
.macro SWITCH_C_TO_OCAML
        ldr     sp, Cstack_sp(sp)
.endm

/* Save all of the registers that may be in use to a free gc_regs bucket
   and store ALLOC_PTR and TRAP_PTR back to Caml_state
   At the end the saved registers are placed in Caml_state(gc_regs)
 */
.macro SAVE_ALL_REGS
    /* First, save the young_ptr & exn_handler */
        str     alloc_ptr, Caml_state(young_ptr)
        str     trap_ptr, Caml_state(exn_handler)
    /* Now, use alloc_ptr (which we just saved) to point to the gc_regs
       bucket */
        ldr     alloc_ptr, Caml_state(gc_regs_buckets)
    /* We save r12 first to allow it to be scratch */ \
        str     r12, [alloc_ptr, 32]
        ldr     r12, [alloc_ptr, 0] /* next ptr */
        str     r12, Caml_state(gc_regs_buckets)
    /* Save allocatable registers */
        str     r0, [alloc_ptr, 0]
        str     r1, [alloc_ptr, 4]
        str     r2, [alloc_ptr, 8]
        str     r3, [alloc_ptr, 12]
        str     r4, [alloc_ptr, 16]
        str     r5, [alloc_ptr, 20]
        str     r6, [alloc_ptr, 24]
        str     r7, [alloc_ptr, 28]
    /*  str     r12, [alloc_ptr, 32] - done above */
    /* Save caller floating-point registers */
#if defined(SYS_linux_eabihf) || defined(SYS_netbsd)
        str     d0, [alloc_ptr, 32]
        str     d1, [alloc_ptr, 40]
        str     d2, [alloc_ptr, 48]
        str     d3, [alloc_ptr, 56]
        str     d4, [alloc_ptr, 64]
        str     d5, [alloc_ptr, 72]
        str     d6, [alloc_ptr, 80]
        str     d7, [alloc_ptr, 88]
        str     alloc_ptr, Caml_state(gc_regs)
#endif
.endm

/* Undo SAVE_ALL_REGS by loading the registers saved in Caml_state(gc_regs)
   and refreshing ALLOC_PTR & TRAP_PTR from Caml_state */
.macro RESTORE_ALL_REGS
        ldr     alloc_ptr, Caml_state(gc_regs)
    /* Restore registers*/
        ldr     r0, [alloc_ptr, 0]
        ldr     r1, [alloc_ptr, 4]
        ldr     r2, [alloc_ptr, 8]
        ldr     r3, [alloc_ptr, 12]
        ldr     r4, [alloc_ptr, 16]
        ldr     r5, [alloc_ptr, 20]
        ldr     r6, [alloc_ptr, 24]
        ldr     r7, [alloc_ptr, 28]
        ldr     r12, [alloc_ptr, 32]
    /* Save caller floating-point registers */
#if defined(SYS_linux_eabihf) || defined(SYS_netbsd)
        ldr     d0, [alloc_ptr, 40]
        ldr     d1, [alloc_ptr, 48]
        ldr     d2, [alloc_ptr, 56]
        ldr     d3, [alloc_ptr, 64]
        ldr     d4, [alloc_ptr, 72]
        ldr     d5, [alloc_ptr, 80]
        ldr     d6, [alloc_ptr, 88]
        ldr     d7, [alloc_ptr, 96]
        ldr     alloc_ptr, Caml_state(gc_regs)
.endm

/* Allocation functions and GC interface */
        TEXT_SECTION(caml_system__code_begin)
        .globl  caml_system__code_begin
caml_system__code_begin:

/* XXX caml_call_realloc_stack */

FUNCTION(caml_call_gc)
        CFI_STARTPROC
.Lcaml_call_gc:
    /* Save return address */
        str     lr, [sp, -4]!
    /* Store all registers (including ALLOC_PTR & TRAP_PTR) */
        SAVE_ALL_REGS
        SWITCH_OCAML_TO_C
    /* Call the garbage collector */
        bl      caml_garbage_collection
        SWITCH_C_TO_OCAML
        RESTORE_ALL_REGS
    /* Free stack space and Return to caller */
        ldr     lr, [sp], 4
        bx      lr
        CFI_ENDPROC
        .size   caml_call_gc, .-caml_call_gc

FUNCTION(caml_alloc1)
        CFI_STARTPROC
        sub     alloc_ptr, alloc_ptr, 8
        ldr     r7, Caml_state(young_limit)
        cmp     alloc_ptr, r7
        bcc     .Lcaml_call_gc
        bx      lr
        CFI_ENDPROC
        .size   caml_alloc1, .-caml_alloc1

FUNCTION(caml_alloc2)
        CFI_STARTPROC
        sub     alloc_ptr, alloc_ptr, 12
        ldr     r7, Caml_state(young_limit)
        cmp     alloc_ptr, r7
        bcc     .Lcaml_call_gc
        bx      lr
        CFI_ENDPROC
        .size   caml_alloc2, .-caml_alloc2

FUNCTION(caml_alloc3)
        CFI_STARTPROC
        sub     alloc_ptr, alloc_ptr, 16
        ldr     r7, Caml_state(young_limit)
        cmp     alloc_ptr, r7
        bcc     .Lcaml_call_gc
        bx      lr
        CFI_ENDPROC
        .size   caml_alloc3, .-caml_alloc3

FUNCTION(caml_allocN)
        CFI_STARTPROC
        sub     alloc_ptr, alloc_ptr, r7
        ldr     r7, Caml_state(young_limit)
        cmp     alloc_ptr, r7
        bcc     .Lcaml_call_gc
        bx      lr
        CFI_ENDPROC
        .size   caml_allocN, .-caml_allocN

/* Call a C function from OCaml */
/* Function to call is in r7 */

FUNCTION(caml_c_call)
        CFI_STARTPROC
    /* Record lowest stack address and return address */
        str     lr, Caml_state(last_return_address)
        str     sp, Caml_state(bottom_of_stack)
    /* Preserve return address in callee-save register r4 */
        mov     r4, lr
        CFI_REGISTER(lr, r4)
    /* Make the exception handler alloc ptr available to the C code */
        str     alloc_ptr, Caml_state(young_ptr)
        str     trap_ptr, Caml_state(exception_pointer)
    /* Call the function */
        blx     r7
    /* Reload alloc ptr */
        ldr     alloc_ptr, Caml_state(young_ptr)
    /* Return */
        bx      r4
        CFI_ENDPROC
        .size   caml_c_call, .-caml_c_call

/* Start the OCaml program */

FUNCTION(caml_start_program)
        CFI_STARTPROC
        ldr     r12, =caml_program

/* Code shared with caml_callback* */
/* Address of OCaml code to call is in r12 */
/* Arguments to the OCaml code are in r0...r3 */

.Ljump_to_caml:
#if defined(SYS_linux_eabihf) || defined(SYS_netbsd)
    /* Save callee-save floating-point registers */
        vpush   {d8-d15}; CFI_ADJUST(64)
#endif
    /* Save return address and callee-save registers */
        push    {r4-r8,r10,r11,lr}; CFI_ADJUST(32)      /* 8-byte alignment */
#if defined(SYS_linux_eabihf) || defined(SYS_netbsd)
        CFI_OFFSET(lr, -68)
#else
        CFI_OFFSET(lr, -4)
#endif
        ldr     domain_state_ptr, =Caml_state
        ldr     domain_state_ptr, [domain_state_ptr]
    /* Setup a callback link on the stack */
        sub     sp, sp, 16; CFI_ADJUST(16)              /* 8-byte alignment */
        ldr     r4, Caml_state(bottom_of_stack)
        ldr     r5, Caml_state(last_return_address)
        ldr     r6, Caml_state(gc_regs)
        str     r4, [sp, 0]
        str     r5, [sp, 4]
        str     r6, [sp, 8]
    /* Setup a trap frame to catch exceptions escaping the OCaml code */
        sub     sp, sp, 8; CFI_ADJUST(8)
        ldr     r5, =.Ltrap_handler
        ldr     r4, Caml_state(exception_pointer)
        str     r4, [sp, 0]
        str     r5, [sp, 4]
        mov     trap_ptr, sp
    /* Reload allocation pointer */
        ldr     alloc_ptr, Caml_state(young_ptr)
    /* Call the OCaml code */
        blx     r12
.Lcaml_retaddr:
    /* Pop the trap frame, restoring caml_exception_pointer */
        ldr     r5, [sp, 0]
        str     r5, Caml_state(exception_pointer)
        add     sp, sp, 8; CFI_ADJUST(-8)
    /* Pop the callback link, restoring the global variables */
.Lreturn_result:
        ldr     r5, [sp, 0]
        str     r5, Caml_state(bottom_of_stack)
        ldr     r5, [sp, 4]
        str     r5, Caml_state(last_return_address)
        ldr     r5, [sp, 8]
        str     r5, Caml_state(gc_regs)
        add     sp, sp, 16; CFI_ADJUST(-16)
    /* Update allocation pointer */
        str     alloc_ptr, Caml_state(young_ptr)
    /* Reload callee-save registers and return address */
        pop     {r4-r8,r10,r11,lr}; CFI_ADJUST(-32)
#if defined(SYS_linux_eabihf) || defined(SYS_netbsd)
    /* Reload callee-save floating-point registers */
        vpop    {d8-d15}; CFI_ADJUST(-64)
#endif
        bx      lr
        CFI_ENDPROC
        .type   .Lcaml_retaddr, %function
        .size   .Lcaml_retaddr, .-.Lcaml_retaddr
        .size   caml_start_program, .-caml_start_program

/* The trap handler */

        .align  2
.Ltrap_handler:
        CFI_STARTPROC
    /* Save exception pointer */
        str     trap_ptr, Caml_state(exception_pointer)
    /* Encode exception bucket as an exception result */
        orr     r0, r0, 2
    /* Return it */
        b       .Lreturn_result
        CFI_ENDPROC
        .type   .Ltrap_handler, %function
        .size   .Ltrap_handler, .-.Ltrap_handler

/* Raise an exception from OCaml */

FUNCTION(caml_raise_exn)
        CFI_STARTPROC
    /* Test if backtrace is active */
        ldr     r1, Caml_state(backtrace_active)
        cbz     r1, 1f
    /* Preserve exception bucket in callee-save register r4 */
        mov     r4, r0
    /* Stash the backtrace */
        mov     r1, lr                          /* arg2: pc of raise */
        mov     r2, sp                          /* arg3: sp of raise */
        mov     r3, trap_ptr                    /* arg4: sp of handler */
        bl      caml_stash_backtrace
    /* Restore exception bucket */
        mov     r0, r4
1:  /* Cut stack at current trap handler */
        mov     sp, trap_ptr
    /* Pop previous handler and addr of trap, and jump to it */
        pop     {trap_ptr, pc}
        CFI_ENDPROC
        .size   caml_raise_exn, .-caml_raise_exn

/* Raise an exception from C */

FUNCTION(caml_raise_exception)
        CFI_STARTPROC
    /* Load the domain state ptr */
        mov     domain_state_ptr, r0
    /* Load exception bucket */
        mov     r0, r1
    /* Reload trap ptr and alloc ptr */
        ldr     trap_ptr, Caml_state(exception_pointer)
        ldr     alloc_ptr, Caml_state(young_ptr)
    /* Test if backtrace is active */
        ldr     r1, Caml_state(backtrace_active)
        cbz     r1, 1f
    /* Preserve exception bucket in callee-save register r4 */
        mov     r4, r0
        ldr     r1, Caml_state(last_return_address) /* arg2: pc of raise */
        ldr     r2, Caml_state(bottom_of_stack)     /* arg3: sp of raise */
        mov     r3, trap_ptr                        /* arg4: sp of handler */
        bl      caml_stash_backtrace
    /* Restore exception bucket */
        mov     r0, r4
1:  /* Cut stack at current trap handler */
        mov     sp, trap_ptr
    /* Pop previous handler and addr of trap, and jump to it */
        pop     {trap_ptr, pc}
        CFI_ENDPROC
        .size   caml_raise_exception, .-caml_raise_exception

/* Callback from C to OCaml */

FUNCTION(caml_callback_asm)
        CFI_STARTPROC
    /* Initial shuffling of arguments */
    /* (r0 = Caml_state, r1 = closure, [r2] = first arg) */
        ldr     r0, [r2]        /* r0 = first arg */
                                /* r1 = closure environment */
        ldr     r12, [r1]       /* code pointer */
        b       .Ljump_to_caml
        CFI_ENDPROC
        .size   caml_callback_asm, .-caml_callback_asm

FUNCTION(caml_callback2_asm)
        CFI_STARTPROC
    /* Initial shuffling of arguments */
    /* (r0 = Caml_state, r1 = closure, [r2] = arg1, [r2,4] = arg2) */
        mov     r12, r1
        ldr     r0, [r2]          /* r0 = first arg */
        ldr     r1, [r2,4]        /* r1 = second arg */
        mov     r2, r12           /* r2 = closure environment */
        ldr     r12, =caml_apply2
        b       .Ljump_to_caml
        CFI_ENDPROC
        .size   caml_callback2_asm, .-caml_callback2_asm

FUNCTION(caml_callback3_asm)
        CFI_STARTPROC
    /* Initial shuffling of arguments */
    /* (r0 = Caml_state, r1 = closure, [r2] = arg1, [r2,4] = arg2,
        [r2,8] = arg3) */
        mov     r3, r1            /* r3 = closure environment */
        ldr     r0, [r2]          /* r0 = first arg */
        ldr     r1, [r2,4]        /* r1 = second arg */
        ldr     r2, [r2,8]        /* r2 = third arg */
        ldr     r12, =caml_apply3
        b       .Ljump_to_caml
        CFI_ENDPROC
        .size   caml_callback3_asm, .-caml_callback3_asm

FUNCTION(caml_ml_array_bound_error)
        CFI_STARTPROC
    /* Load address of [caml_array_bound_error_asm] in r7 */
        ldr     r7, =caml_array_bound_error_asm
    /* Call that function */
        b       caml_c_call
        CFI_ENDPROC
        .size   caml_ml_array_bound_error, .-caml_ml_array_bound_error

        TEXT_SECTION(caml_system__code_end)
        .globl  caml_system__code_end
caml_system__code_end:

/* GC roots for callback */

        .data
        .align  2
        .globl  caml_system.frametable
caml_system.frametable:
        .word   1               /* one descriptor */
        .word   .Lcaml_retaddr  /* return address into callback */
        .short  -1              /* negative frame size => use callback link */
        .short  0               /* no roots */
        .align  2
        .type   caml_system.frametable, %object
        .size   caml_system.frametable, .-caml_system.frametable

/* Mark stack as non-executable */
        .section .note.GNU-stack,"",%progbits
