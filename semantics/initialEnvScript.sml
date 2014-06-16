(*Generated by Lem from initialEnv.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasives_extraTheory libTheory astTheory semanticPrimitivesTheory typeSystemTheory elabTheory;

val _ = numLib.prefer_num();



val _ = new_theory "initialEnv"

(*open import Pervasives_extra*)
(*open import Lib*)
(*open import Ast*)
(*open import SemanticPrimitives*)
(*open import TypeSystem*)
(*open import Elab*)

(* The initial constructor environment for the operational semantics *)
(*val init_envC : envC*)
val _ = Define `
 (init_envC =
  (emp,   
(("NONE", ( 0, TypeId (Short "option"))) ::   
(("SOME", ( 1, TypeId (Short "option"))) ::   
(("nil", ( 0, TypeId (Short "list"))) ::   
(("::", ( 2, TypeId (Short "list"))) ::
   MAP (\ cn .  (cn, ( 0, TypeExn (Short cn)))) ["Subscript";"Bind"; "Div"; "Eq"]))))))`;


(* The initial value environment for the operational semantics *)
(*val init_env : envE*)
val _ = Define `
 (init_env =  
([("+", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opn Plus) [Var (Short "x"); Var (Short "y")])));
   ("-", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opn Minus) [Var (Short "x"); Var (Short "y")])));
   ("*", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opn Times) [Var (Short "x"); Var (Short "y")])));
   ("div", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opn Divide) [Var (Short "x"); Var (Short "y")])));
   ("mod", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opn Modulo) [Var (Short "x"); Var (Short "y")])));
   ("<", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opb Lt) [Var (Short "x"); Var (Short "y")])));
   (">", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opb Gt) [Var (Short "x"); Var (Short "y")])));
   ("<=", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opb Leq) [Var (Short "x"); Var (Short "y")])));
   (">=", Closure ([],init_envC,[]) "x" (Fun "y" (App (Opb Geq) [Var (Short "x"); Var (Short "y")])));
   ("=", Closure ([],init_envC,[]) "x" (Fun "y" (App Equality [Var (Short "x"); Var (Short "y")])));
   (":=", Closure ([],init_envC,[]) "x" (Fun "y" (App Opassign [Var (Short "x"); Var (Short "y")])));
   ("~", Closure ([],init_envC,[]) "x" (App (Opn Minus) [Lit (IntLit(( 0 : int))); Var (Short "x")]));
   ("!", Closure ([],init_envC,[]) "x" (App Opderef [Var (Short "x")]));
   ("ref", Closure ([],init_envC,[]) "x" (App Opref [Var (Short "x")]))]))`;



(* The initial type environment for the type system *)
(*val init_tenv : tenvE*)
val _ = Define `
 (init_tenv =  
(FOLDR 
    (\ (tn,tvs,t) tenv .  Bind_name tn tvs t tenv) 
    Empty 
    [("+", 0, Tfn Tint (Tfn Tint Tint));
     ("-", 0, Tfn Tint (Tfn Tint Tint));
     ("*", 0, Tfn Tint (Tfn Tint Tint));
     ("div", 0, Tfn Tint (Tfn Tint Tint));
     ("mod", 0, Tfn Tint (Tfn Tint Tint));
     ("<", 0, Tfn Tint (Tfn Tint Tbool));
     (">", 0, Tfn Tint (Tfn Tint Tbool));
     ("<=", 0, Tfn Tint (Tfn Tint Tbool));
     (">=", 0, Tfn Tint (Tfn Tint Tbool));
     ("=", 1, Tfn (Tvar_db( 0)) (Tfn (Tvar_db( 0)) Tbool));
     (":=", 1, Tfn (Tref (Tvar_db( 0))) (Tfn (Tvar_db( 0)) Tunit));
     ("~", 0, Tfn Tint Tint);
     ("!", 1, Tfn (Tref (Tvar_db( 0))) (Tvar_db( 0)));
     ("ref", 1, Tfn (Tvar_db( 0)) (Tref (Tvar_db( 0))))]))`;


(* The initial constructor environment for the type system *)
(*val init_tenvC : tenvC*)
val _ = Define `
 (init_tenvC =
  (emp,   
(("NONE", (["'a"], [], TypeId (Short "option"))) ::   
(("SOME", (["'a"], [Tvar "'a"], TypeId (Short "option"))) ::   
(("nil", (["'a"], [], TypeId (Short "list"))) ::   
(("::", (["'a"], [Tvar "'a"; Tapp [Tvar "'a"] (TC_name (Short "list"))], TypeId (Short "list"))) ::
   MAP (\ cn .  (cn, ([], [], TypeExn (Short cn)))) ["Subscript";"Bind"; "Div"; "Eq"]))))))`;


(* The initial mapping of type names to primitive type constructors, for the elaborator *)
(*val init_type_bindings : tdef_env*)
val _ = Define `
 (init_type_bindings =  
([("int", TC_int);
   ("bool", TC_bool);
   ("ref", TC_ref);
   ("exn", TC_exn);
   ("unit", TC_unit);
   ("list", TC_name (Short "list"));
   ("option", TC_name (Short "option"))]))`;


(* The modules, types, and exceptions that have been declared, for the type system to detect duplicates*)
(*val init_decls : decls*)
val _ = Define `
 (init_decls =
  ({}, { Short "option"; Short "list" }, { Short "Subscript"; Short "Bind"; Short "Div"; Short "Eq" }))`;

val _ = export_theory()

