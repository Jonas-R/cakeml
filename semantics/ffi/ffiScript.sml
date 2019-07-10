(*Generated by Lem from ffi.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory lem_pervasives_extraTheory libTheory;

val _ = numLib.prefer_num();



val _ = new_theory "ffi"

(*
  An oracle says how to perform an ffi call based on its internal
  state, represented by the type variable 'ffi.
*)
(*open import Pervasives*)
(*open import Pervasives_extra*)
(*open import Lib*)


(* supported prmitive C values  *)

val _ = Hol_datatype `
 c_primv = C_boolv of bool | C_intv of int`;



val _ = Hol_datatype `
c_array_conf =
<| mutable     : bool
 ; with_length : bool
 |>`

(* C types for input/output arguments *)
val _ = Hol_datatype `
 c_type = C_bool | C_int | C_array of c_array_conf`;

(* C values *)
val _ = Hol_datatype `
 c_value = C_primv of c_primv | C_arrayv of word8 list`;

val _ = Hol_datatype `
c_funsig =
<| mlname      : string
 ; cname       : string
 ; retty       : c_type option (* NONE represents unit *)
 ; args        : c_type list
|>`

(*  arg_ok :: "c_type ⇒ c_value ⇒ bool" *)
val _ = Define `arg_ok t v =
  case v of
    C_arrayv _ => (case t of C_array _ => T | _ => F)
  | C_primv(C_boolv _) => (t = C_bool)
  | C_primv(C_intv _) => (t = C_int)
`

(*   args_ok :: "c_funsig ⇒ c_value list ⇒ bool" *)
(* args to be passed in the signature's sequence *)

val _ = Define `args_ok sig args = LIST_REL arg_ok sig.args args`

(* ret_ok :: "c_type option ⇒ c_value option ⇒ bool" *)
val _ = Define `ret_ok t v =
 ((t = NONE) /\ (v = NONE)) \/ (OPTION_MAP2 arg_ok t (OPTION_MAP C_primv v) = SOME T)`


(* 'a list  -> (num # 'a) list *)

val _ = Define `
  loc_typ ctl = MAPi $, ctl
`

(* byte list list -> (num#c_type) list -> (num#byte list) list *)

val _ = Define `
  (mut_tag_retr [] _ = []) /\
  (mut_tag_retr _ [] = []) /\
  (mut_tag_retr (btl::btls) (ict::icts) =
         case SND ict of C_array conf => if conf.mutable
                                         then (FST ict, btl) :: mut_tag_retr btls icts
                                         else mut_tag_retr (btl::btls) icts
                         | _ =>   mut_tag_retr (btl::btls) icts)
`

(* ('a # 'b list) list -> 'a list -> ('a # 'b list) list *)
val _ = Define `
  (match_cargs btl [] = []) /\
  (match_cargs btl (n::ns) = FILTER (\x. FST x = n) btl ++ match_cargs btl ns)
`

val _ = Define `
  ident_elems l = if CARD (set l) = 1 then T else F
`
(* c_type list -> 'a list -> num list -> 'a list  *)
val _ = Define `
  als_vals ctl btl als = MAP (\x. SND x) (match_cargs (mut_tag_retr btl (loc_typ ctl)) als)
`


val _ = Define `
  als_vals_ok ctl btl als =  ident_elems (als_vals ctl btl als)
`

(*  “:c_type list -> α list -> num list list -> bool” *)

val _ = Define `
  als_ok ctl btl alsl =  (FILTER (\b. b = F) (MAP (\nl. ident_elems (als_vals ctl btl nl) ) alsl) = [])
`


val is_mutty = Define `
 is_mutty ty =
  (case ty of C_array c => c.mutable
   | _ => F)
 `

val _ = Define `(mutargs [] _ = [])
 /\ (mutargs _ [] = [])
 /\ (mutargs (ty::tys) (v::vs) =
     (case v of
        C_arrayv v =>
        (case ty of C_array c => if c.mutable then v::mutargs tys vs
                                else mutargs tys vs
                  | _ => mutargs tys vs)
      | _ => mutargs tys vs))`


val _ = Hol_datatype `
 ffi_outcome = FFI_failed | FFI_diverged`;

(* Oracle_return encodes the new state, list of word8 list of the output, and the return value *)
val _ = Hol_datatype `
 oracle_result = Oracle_return of 'ffi => word8 list list  => c_primv option
               | Oracle_final of ffi_outcome`;



(* reinstating num list list to treat aliasing *)
val _ = type_abbrev((*  'ffi *) "oracle_function" , ``: 'ffi -> c_value list -> num list list -> 'ffi oracle_result``);
val _ = type_abbrev((*  'ffi *) "oracle" , ``: string -> 'ffi oracle_function``);

(* An I/O event, IO_event s bytes bytes2, represents the call of FFI function s with
* immutable input bytes and mutable input map fst bytes2,
* returning map snd bytes2 in the mutable array. TODO: update *)

val _ = Hol_datatype `
 io_event = IO_event of string => c_value list => word8 list list => c_primv option`;


val _ = Hol_datatype `
 final_event = Final_event of string => c_value list => ffi_outcome`;


val _ = Hol_datatype `
(*  'ffi *) ffi_state =
<| oracle      : 'ffi oracle
 ; ffi_state   : 'ffi
 ; io_events   : io_event list
 ; signatures  : c_funsig list (* new *)
 |>`;


(*val initial_ffi_state : forall 'ffi. oracle 'ffi -> 'ffi -> ffi_state 'ffi*)
val _ = Define `
 ((initial_ffi_state:(string -> 'ffi oracle_function) -> 'ffi -> c_funsig list -> 'ffi ffi_state) oc ffi sigs =
 (<| oracle      := oc
 ; ffi_state   := ffi
 ; io_events   := ([])
 ; signatures  := sigs
 |>))`;


val _ = Define `
   debug_ffi_ok st = ?sign. (FIND (λsg. sg.mlname = "") st.signatures = SOME sign) /\
                            (!args. mutargs sign.args args = []) /\ (sign.retty = NONE)
`
val _ = Define `
  valid_ffi_name n sign st = (FIND (λsg. sg.mlname = n) st.signatures = SOME sign)
`


val _ = Define `
  eq_len sign args newargs = LIST_REL (λx y. LENGTH x = LENGTH y) (mutargs sign.args args) newargs

`

val _ = Define `
  ffi_oracle_ok st =
  debug_ffi_ok st /\ (!n sign args st' ffi newargs retv als.
           valid_ffi_name n sign st
           /\ args_ok sign args
           /\ (st.oracle n ffi args als = Oracle_return st' newargs retv)
           ==> ret_ok sign.retty retv /\ als_ok sign.args newargs als
               /\ eq_len sign args newargs)
    `

val _ = Hol_datatype `
 ffi_result = FFI_return of 'ffi ffi_state => word8 list list  => c_primv option
            | FFI_final of final_event`;


val _ = Define `
 call_FFI st n sign args als =
   if ~ (n = "") then
     case st.oracle n st.ffi_state args als of
         Oracle_return ffi' newargs retv =>
           if ret_ok sign.retty retv /\ als_ok sign.args newargs als /\ eq_len sign args newargs then
              SOME (FFI_return (st with<| ffi_state := ffi'
                                   ; io_events := st.io_events ++ [IO_event n args newargs retv]
                         |>) newargs retv)
           else NONE
        | Oracle_final outcome => SOME (FFI_final (Final_event n args outcome))
  else SOME (FFI_return st [] NONE)`;



val _ = Hol_datatype `
 outcome = Success | Resource_limit_hit | FFI_outcome of final_event`;


(* A program can Diverge, Terminate, or Fail. We prove that Fail is
   avoided. For Diverge and Terminate, we keep track of what I/O
   events are valid I/O events for this behaviour. *)
val _ = Hol_datatype `
 behaviour =
    (* There cannot be any non-returning FFI calls in a diverging
       exeuction. The list of I/O events can be finite or infinite,
       hence the llist (lazy list) type. *)
    Diverge of  io_event llist
    (* Terminating executions can only perform a finite number of
       FFI calls. The execution can be terminated by a non-returning
       FFI call. *)
  | Terminate of outcome => io_event list
    (* Failure is a behaviour which we prove cannot occur for any
       well-typed program. *)
  | Fail`;


(* trace-based semantics can be recovered as an instance of oracle-based
 * semantics as follows. *)

(*val trace_oracle : oracle (llist io_event)*)
val _ = Define `
 ((trace_oracle:string ->(io_event)llist ->(c_value)list ->((io_event)llist)oracle_result) s io_trace args=
   ((case LHD io_trace of
    SOME (IO_event s' args' newargs retv) =>
      if (s = s') /\ (args = args') then
        Oracle_return (THE (LTL io_trace)) newargs retv
      else Oracle_final FFI_failed
  | _ => Oracle_final FFI_failed
  )))`;

val _ = export_theory()
