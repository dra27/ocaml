(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Asttypes
open Types
open Data_types
open Typedtree

type type_forcing_context =
  | If_conditional
  | If_no_else_branch
  | While_loop_conditional
  | While_loop_body
  | For_loop_start_index
  | For_loop_stop_index
  | For_loop_body
  | Assert_condition
  | Sequence_left_hand_side
  | When_guard

type type_expected = {
  ty: type_expr;
  explanation: type_forcing_context option;
}

module Datatype_kind = struct
  type t = Record | Variant

  let type_name = function
    | Record -> "record"
    | Variant -> "variant"

  let label_name = function
    | Record -> "field"
    | Variant -> "constructor"
end

type wrong_name = {
  type_path: Path.t;
  kind: Datatype_kind.t;
  name: string loc;
  valid_names: string list;
}

type wrong_kind_context =
  | Pattern
  | Expression of type_forcing_context option

type wrong_kind_sort =
  | Constructor
  | Record
  | Boolean
  | List
  | Unit
type pattern_variable_kind =
  | Std_var
  | As_var
  | Continuation_var

type pattern_variable =
  {
    pv_id: Ident.t;
    pv_type: type_expr;
    pv_loc: Location.t;
    pv_kind: pattern_variable_kind;
    pv_attributes: Typedtree.attributes;
    pv_uid : Uid.t;
  }

let mk_expected ?explanation ty = { ty; explanation; }

type existential_restriction =
  | At_toplevel
  | In_group
  | In_rec
  | With_attributes
  | In_class_args
  | In_class_def
  | In_self_pattern

type existential_binding =
  | Bind_already_bound
  | Bind_not_in_scope
  | Bind_non_locally_abstract

type error =
  | Constructor_arity_mismatch of Longident.t * int * int
  | Label_mismatch of Longident.t * Errortrace.unification_error
  | Pattern_type_clash :
      Errortrace.unification_error * Parsetree.pattern_desc option -> error
  | Or_pattern_type_clash of Ident.t * Errortrace.unification_error
  | Multiply_bound_variable of string
  | Orpat_vars of Ident.t * Ident.t list
  | Expr_type_clash of
      Errortrace.unification_error * type_forcing_context option
      * Parsetree.expression option
  | Function_arity_type_clash of
      { syntactic_arity :  int;
        type_constraint : type_expr;
        trace : Errortrace.unification_error;
      }
  (* [Function_arity_type_clash { syntactic_arity = n; type_constraint; trace }]
     is the type error for the specific case where an n-ary function is
     constrained at a type with an arity less than n, e.g.:
     {[
       type (_, _) eq = Eq : ('a, 'a) eq
       let bad : type a. ?opt:(a, int -> int) eq -> unit -> a =
         fun ?opt:(Eq = assert false) () x -> x + 1
     ]}

     [type_constraint] is the user-written polymorphic type (in this example
     [?opt:(a, int -> int) eq -> unit -> a]) that causes this type clash, and
     [trace] is the unification error that signaled the issue.
  *)
  | Apply_non_function of {
      funct : Typedtree.expression;
      func_ty : type_expr;
      res_ty : type_expr;
      previous_arg_loc : Location.t;
      extra_arg_loc : Location.t;
    }
  | Apply_wrong_label of arg_label * type_expr * bool
  | Label_multiply_defined of string
  | Label_missing of Ident.t list
  | Label_not_mutable of Longident.t
  | Wrong_name of string * type_expected * wrong_name
  | Name_type_mismatch of
      Datatype_kind.t * Longident.t * (Path.t * Path.t) * (Path.t * Path.t) list
  | Invalid_format of string
  | Not_an_object of type_expr * type_forcing_context option
  | Undefined_method of type_expr * string * string list option
  | Undefined_self_method of string * string list
  | Virtual_class of Longident.t
  | Private_type of type_expr
  | Private_label of Longident.t * type_expr
  | Private_constructor of constructor_description * type_expr
  | Unbound_instance_variable of string * string list
  | Instance_variable_not_mutable of string
  | Not_subtype of Errortrace.Subtype.error
  | Outside_class
  | Value_multiply_overridden of string
  | Coercion_failure of
      Errortrace.expanded_type * Errortrace.unification_error * bool
  | Not_a_function of type_expr * type_forcing_context option
  | Too_many_arguments of type_expr * type_forcing_context option
  | Abstract_wrong_label of
      { got           : arg_label
      ; expected      : arg_label
      ; expected_type : type_expr
      ; explanation   : type_forcing_context option
      }
  | Not_a_polymorphic_variant_type of Longident.t
  | Incoherent_label_order
  | Less_general of string * Errortrace.unification_error
  | Modules_not_allowed
  | Cannot_infer_signature
  | Not_a_packed_module of type_expr
  | Unexpected_existential of existential_restriction * string
  | Invalid_interval
  | Invalid_for_loop_index
  | No_value_clauses
  | Exception_pattern_disallowed
  | Mixed_value_and_exception_patterns_under_guard
  | Effect_pattern_below_toplevel
  | Invalid_continuation_pattern
  | Inlined_record_escape
  | Inlined_record_expected
  | Unrefuted_pattern of pattern
  | Invalid_extension_constructor_payload
  | Not_an_extension_constructor
  | Invalid_atomic_loc_payload
  | Label_not_atomic of Longident.t
  | Atomic_in_pattern of Longident.t
  | Literal_overflow of string
  | Unknown_literal of string * char
  | Illegal_letrec_pat
  | Illegal_letrec_expr
  | Illegal_class_expr
  | Letop_type_clash of string * Errortrace.unification_error
  | Andop_type_clash of string * Errortrace.unification_error
  | Bindings_type_clash of Errortrace.unification_error
  | Unbound_existential of Ident.t list * type_expr
  | Bind_existential of existential_binding * Ident.t * type_expr
  | Missing_type_constraint
  | Wrong_expected_kind of wrong_kind_sort * wrong_kind_context * type_expr
  | Expr_not_a_record_type of type_expr
  | Constructor_labeled_arg
  | Partial_tuple_pattern_bad_type
  | Extra_tuple_label of string option * type_expr
  | Missing_tuple_label of string option * type_expr
  | Repeated_tuple_exp_label of string
  | Repeated_tuple_pat_label of string
  | Optional_poly_param of string

exception Error of Location.t * Env.t * error

(* Forward declaration, to be filled in by Typemod.type_module *)

let type_module =
  ref ((fun _env _md -> assert false) :
       Env.t -> Parsetree.module_expr -> Typedtree.module_expr * Shape.t)

let type_str_item =
  ref ((fun _env _sstr -> assert false) :
         Env.t -> Parsetree.structure_item -> Typedtree.structure_item * Env.t)

(* Forward declaration, to be filled in by Typemod.type_open *)

let type_open :
  (?used_slot:bool ref -> override_flag -> Env.t -> Location.t ->
   Longident.t loc -> Path.t * Env.t)
    ref =
  ref (fun ?used_slot:_ _ -> assert false)

let type_open_decl :
  (?used_slot:bool ref -> Env.t -> Parsetree.open_declaration
   -> open_declaration * Types.signature * Env.t)
    ref =
  ref (fun ?used_slot:_ _ -> assert false)

(* Forward declaration, to be filled in by Typemod.type_package *)

let type_package =
  ref (fun _ -> assert false)

(* Forward declaration, to be filled in by Typeclass.class_structure *)
let type_object =
  ref (fun _env _s -> assert false :
       Env.t -> Location.t -> Parsetree.class_structure ->
         Typedtree.class_structure * string list)
let type_binding =
  ref ((fun _env _rec_flag _spat_sexp_list -> assert false) :
        Env.t -> rec_flag ->
          Parsetree.value_binding list ->
          Typedtree.value_binding list * Env.t)
let type_let =
  ref ((fun _existential_ctx _env _rec_flag _spat_sexp_list -> assert false) :
        existential_restriction -> Env.t -> rec_flag ->
          Parsetree.value_binding list ->
          Typedtree.value_binding list * Env.t)
let type_expression =
  ref ((fun _env _sexp -> assert false) :
        Env.t -> Parsetree.expression -> Typedtree.expression)
let type_class_arg_pattern =
  ref ((fun _cl_num _val_env _met_env _l _spat -> assert false) :
        string -> Env.t -> Env.t -> arg_label -> Parsetree.pattern ->
        Typedtree.pattern *
        (Ident.t * Ident.t * type_expr) list *
        Env.t * Env.t)
let type_self_pattern =
  ref ((fun _env _spat -> assert false) :
        Env.t -> Parsetree.pattern ->
        Typedtree.pattern * pattern_variable list)
let check_partial =
  ref ((fun ?lev:_ _env _expected_ty _loc _cases -> assert false) :
        ?lev:int -> Env.t -> type_expr ->
        Location.t -> Typedtree.value Typedtree.case list -> Typedtree.partial)
let type_expect =
  ref ((fun _env _e _ty -> assert false) :
        Env.t -> Parsetree.expression ->
        type_expected -> Typedtree.expression)
let type_exp =
  ref ((fun _env _e -> assert false) :
        Env.t -> Parsetree.expression -> Typedtree.expression)

let type_approx =
  ref ((fun _env _sexp _ty_expected -> assert false) :
        Env.t -> Parsetree.expression -> type_expr -> unit)
let type_argument =
  ref ((fun _env _e _t1 _t2 -> assert false) :
        Env.t -> Parsetree.expression ->
        type_expr -> type_expr -> Typedtree.expression)

let option_some =
  ref ((fun _env _texp -> assert false) :
  Env.t -> Typedtree.expression -> Typedtree.expression)
let option_none =
  ref ((fun _env _ty _loc -> assert false) :
  Env.t -> type_expr -> Location.t -> Typedtree.expression)
let extract_option_type =
  ref ((fun _env _ty -> assert false) :
  Env.t -> type_expr -> type_expr)
let generalizable =
  ref ((fun _level _ty -> assert false) :
  int -> type_expr -> bool)
let reset_delayed_checks =
  ref (fun () -> assert false)
let force_delayed_checks =
  ref (fun () -> assert false)

let has_poly_constraint =
  ref ((fun _spat -> assert false) :
  Parsetree.pattern -> bool)

(* To find reasonable names for let-bound and lambda-bound idents *)

let rec name_pattern default = function
    [] -> Ident.create_local default
  | p :: rem ->
    match p.pat_desc with
      Tpat_var (id, _, _) -> id
    | Tpat_alias(_, id, _, _, _) -> id
    | _ -> name_pattern default rem

let name_cases default lst =
  name_pattern default (List.map (fun c -> c.c_lhs) lst)

(* Hack to allow coercion of self. Will clean-up later. *)
let self_coercion = ref ([] : (Path.t * Location.t list ref) list)

let annotate_recursive_bindings =
  ref ((fun _env _valbinds -> assert false) :
  Env.t -> Typedtree.value_binding list -> Typedtree.value_binding list)
let check_recursive_class_bindings =
  ref ((fun _env _ids _exprs -> assert false) :
  Env.t -> Ident.t list -> Typedtree.class_expr list -> unit)
