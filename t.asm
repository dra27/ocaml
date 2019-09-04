	EXTRN	caml_call_gc: NEAR
	EXTRN	caml_call_gc1: NEAR
	EXTRN	caml_call_gc2: NEAR
	EXTRN	caml_call_gc3: NEAR
	EXTRN	caml_c_call: NEAR
	EXTRN	caml_allocN: NEAR
	EXTRN	caml_alloc1: NEAR
	EXTRN	caml_alloc2: NEAR
	EXTRN	caml_alloc3: NEAR
	EXTRN	caml_ml_array_bound_error: NEAR
	EXTRN	caml_raise_exn: NEAR
	.DATA
	ALIGN	16
caml_negf_mask LABEL QWORD
	QWORD	08000000000000000H
	QWORD	0
	ALIGN	16
caml_absf_mask LABEL QWORD
	QWORD	07fffffffffffffffH
	QWORD	-1
	.DATA
	PUBLIC	camlT__data_begin
camlT__data_begin LABEL QWORD
	.CODE
	PUBLIC	camlT__code_begin
camlT__code_begin LABEL QWORD
	.DATA
	ALIGN	8
	.DATA
	ALIGN	8
	QWORD	768
	PUBLIC	camlT
camlT LABEL QWORD
	.DATA
	ALIGN	8
	PUBLIC	camlT__gc_roots
camlT__gc_roots LABEL QWORD
	QWORD	camlT
	QWORD	0
	.CODE
	ALIGN	16
	PUBLIC	camlT__entry
camlT__entry:
	sub	rsp, 8
L103:
	mov	rcx, 1
	sub	rsp, 32
	mov	rax, OFFSET __camlMASM$test
	call	QWORD PTR __caml_imp_caml_c_call
L100:
	add	rsp, 32
	mov	rcx, 1
	sub	rsp, 32
	mov	rax, OFFSET __camlMASM$Test
	call	QWORD PTR __caml_imp_caml_c_call
L101:
	add	rsp, 32
	mov	rcx, 1
	sub	rsp, 32
	mov	rax, OFFSET __camlMASM$mov
	call	QWORD PTR __caml_imp_caml_c_call
L102:
	add	rsp, 32
	mov	rax, 1
	add	rsp, 8
	ret
	.DATA
	ALIGN	8
	.CODE
	PUBLIC	camlT__code_end
camlT__code_end LABEL QWORD
	.DATA
 ; relocation table start 
	ALIGN	8
__caml_imp_caml_c_call LABEL QWORD
	QWORD	caml_c_call
 ; relocation table end 
	.DATA
	QWORD	0
	PUBLIC	camlT__data_end
camlT__data_end LABEL QWORD
	QWORD	0
	ALIGN	8
	PUBLIC	camlT__frametable
camlT__frametable LABEL QWORD
	QWORD	3
	QWORD	L102
	WORD	49
	WORD	0
	ALIGN	8
	QWORD	L104
	QWORD	L101
	WORD	49
	WORD	0
	ALIGN	8
	QWORD	L105
	QWORD	L100
	WORD	49
	WORD	0
	ALIGN	8
	QWORD	L106
	ALIGN	8
L106 LABEL QWORD
	DWORD	(L107 - THIS BYTE) + 1073741824
	DWORD	20624
	QWORD	0
	ALIGN	8
L105 LABEL QWORD
	DWORD	(L107 - THIS BYTE) + 1744830464
	DWORD	20768
	QWORD	0
	ALIGN	8
L104 LABEL QWORD
	DWORD	(L107 - THIS BYTE) + -2013265920
	DWORD	20928
	QWORD	0
L107 LABEL QWORD
	BYTE	116,46,109,108,0
	ALIGN	8
 ; Reserved names used 
	OPTION NOKEYWORD:<mov test>
	__camlMASM$Test TEXTEQU <Test>
	__camlMASM$mov TEXTEQU <mov>
	__camlMASM$test TEXTEQU <test>
 ; External functions 
	EXTRN	__camlMASM$Test: NEAR
	EXTRN	__camlMASM$mov: NEAR
	EXTRN	__camlMASM$test: NEAR
	END
