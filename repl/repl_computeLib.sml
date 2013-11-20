structure repl_computeLib = struct
open preamble repl_funTheory ASCIInumbersLib intLib stringLib
open astTheory inferTheory compilerTheory compilerTerminationTheory bytecodeEvalTheory
open repl_computeTheory;

(* add repl definitions to the compset *)

val RES_FORALL_set = prove(``RES_FORALL (set ls) P = EVERY P ls``,rw[RES_FORALL_THM,listTheory.EVERY_MEM])

val bc_fetch_aux_zero = prove(
``∀ls n. bc_fetch_aux ls (K 0) n = el_check n (FILTER ($~ o is_Label) ls)``,
Induct >> rw[compilerLibTheory.el_check_def] >> fs[] >> fsrw_tac[ARITH_ss][] >>
simp[rich_listTheory.EL_CONS,arithmeticTheory.PRE_SUB1])

val _ = computeLib.add_funs
  [terminationTheory.elab_p_def
  ,elabTheory.elab_decs_def
  ,miscTheory.find_index_def
  ,compilerLibTheory.the_def
  ,compilerLibTheory.lunion_def
  ,compilerLibTheory.lshift_def
  ,pat_bindings_def
  ,compile_news_def
  ,toBytecodeTheory.compile_varref_def
  ,CONV_RULE(!Defn.SUC_TO_NUMERAL_DEFN_CONV_hook)compile_def
  ,label_closures_def
  ,remove_mat_var_def
  ,toIntLangTheory.remove_mat_vp_def
  ,mkshift_def
  ,toBytecodeTheory.cce_aux_def
  ,exp_to_Cexp_def
  ,toIntLangTheory.pat_to_Cpat_def
  ,toIntLangTheory.Cpat_vars_def
  ,generalise_def
  ,RES_FORALL_set
  ,bc_fetch_aux_zero
  ]

val _ = let
  open computeLib
in
  set_skip the_compset ``evalcase_CASE`` (SOME 1);
  set_skip the_compset ``list_CASE`` (SOME 1);
  set_skip the_compset ``option_CASE`` (SOME 1);
  set_skip the_compset ``sum_CASE`` (SOME 1);
  set_skip the_compset ``id_CASE`` (SOME 1);
  set_skip the_compset ``tc0_CASE`` (SOME 1);
  set_skip the_compset ``t_CASE`` (SOME 1);
  set_skip the_compset ``lit_CASE`` (SOME 1);
  set_skip the_compset ``pat_CASE`` (SOME 1);
  set_skip the_compset ``lop_CASE`` (SOME 1);
  set_skip the_compset ``opb_CASE`` (SOME 1);
  set_skip the_compset ``opn_CASE`` (SOME 1);
  set_skip the_compset ``op_CASE`` (SOME 1);
  set_skip the_compset ``uop_CASE`` (SOME 1);
  set_skip the_compset ``exp_CASE`` (SOME 1);
  set_skip the_compset ``dec_CASE`` (SOME 1);
  set_skip the_compset ``spec_CASE`` (SOME 1);
  set_skip the_compset ``top_CASE`` (SOME 1);
  set_skip the_compset ``ast_t_CASE`` (SOME 1);
  set_skip the_compset ``ast_pat_CASE`` (SOME 1);
  set_skip the_compset ``ast_exp_CASE`` (SOME 1);
  set_skip the_compset ``ast_dec_CASE`` (SOME 1);
  set_skip the_compset ``ast_spec_CASE`` (SOME 1);
  set_skip the_compset ``ast_top_CASE`` (SOME 1);
  set_skip the_compset ``bc_stack_op_CASE`` (SOME 1);
  set_skip the_compset ``bc_inst_CASE`` (SOME 1);
  set_skip the_compset ``compiler_state_CASE`` (SOME 1);
  set_skip the_compset ``Cpat_CASE`` (SOME 1);
  set_skip the_compset ``exp_to_Cexp_state_CASE`` (SOME 1);
  set_skip the_compset ``compiler_result_CASE`` (SOME 1);
  set_skip the_compset ``call_context_CASE`` (SOME 1);
  set_skip the_compset ``ctbind_CASE`` (SOME 1);
  set_skip the_compset ``COND`` (SOME 1)
end

val _ = computeLib.add_funs [compile_decs_def, compile_print_vals_def]
val eval_compile_primitives = EVAL ``compile_primitives``
val _ = computeLib.del_funs[compile_primitives_def, compile_decs_def, compile_print_vals_def]
val _ = computeLib.add_funs[eval_compile_primitives]

val eval_initial_repl_fun_state = EVAL ``initial_repl_fun_state``
val _ = PolyML.fullGC();
(* too slow!
val eval_initial_bc_state = EVAL ``initial_bc_state``
*)
val _ = computeLib.del_funs[initial_repl_fun_state_def,initial_bc_state_def]
val _ = computeLib.add_funs[eval_initial_repl_fun_state(*,eval_initial_bc_state*)]

(* faster evaluation of the compile_dec *)

val _ = Globals.max_print_depth := 15

fun rbinop_size acc t =
    if is_const t orelse is_var t then acc else rbinop_size (acc + 1) (rand t)
fun lbinop_size acc t =
    if is_const t orelse is_var t then acc else lbinop_size (acc + 1) (lhand t)

fun term_lsplit_after n t = let
  fun recurse acc n t =
    if n <= 0 then (List.rev acc, t)
    else
      let val (fx,y) = dest_comb t
          val (f,x) = dest_comb fx
      in
        recurse (x::acc) (n - 1) y
      end handle HOL_ERR _ => (List.rev acc, t)
in
  recurse [] n t
end

val (app_nil, app_cons) = CONJ_PAIR listTheory.APPEND
fun APP_CONV t = (* don't eta-convert *)
    ((REWR_CONV app_cons THENC RAND_CONV APP_CONV) ORELSEC
     REWR_CONV app_nil) t

fun onechunk n t = let
  val (pfx, sfx) = term_lsplit_after n t
in
  if null pfx orelse listSyntax.is_nil sfx then raise UNCHANGED
  else let
    val pfx_t = listSyntax.mk_list(pfx, type_of (hd pfx))
  in
    APP_CONV (listSyntax.mk_append(pfx_t, sfx)) |> SYM
  end
end

fun chunkify_CONV n t =
    TRY_CONV (onechunk n THENC RAND_CONV (chunkify_CONV n)) t

val Dlet_t = prim_mk_const{Thy = "ast", Name = "Dlet"}
val Dletrec_t = prim_mk_const{Thy = "ast", Name = "Dletrec"}
val Dtype_t = prim_mk_const{Thy = "ast", Name = "Dtype"}
fun declstring t = let
  val (f, args) = strip_comb t
in
  if same_const f Dlet_t then "val " ^ Literal.dest_string_lit (rand (hd args))
  else if same_const f Dletrec_t then
    let
      val (fdecs,_) = listSyntax.dest_list (hd args)
    in
      "fun " ^ Literal.dest_string_lit (hd (pairSyntax.strip_pair (hd fdecs))) ^
      (if length fdecs > 1 then "*" else "")
    end
  else if same_const f Dtype_t then
    let
      val (tydecs,_) = listSyntax.dest_list (hd args)
    in
      "datatype " ^
      Literal.dest_string_lit (hd (tl (pairSyntax.strip_pair (hd tydecs)))) ^
      (if length tydecs > 1 then "*" else "")
    end
  else "??"
end

val (FOLDL_NIL, FOLDL_CONS) = CONJ_PAIR listTheory.FOLDL
val FOLDL_EVAL = let
  (* t is of form FOLDL f acc [e1; e2; e3; .. ] and f is evaluated with EVAL. *)
  fun eval n t = (PolyML.fullGC(); print ("(" ^ declstring (rand t) ^ ")");
                  EVAL t before print (Int.toString n ^ " "))
  fun recurse n t =
      (REWR_CONV FOLDL_NIL ORELSEC
       (REWR_CONV FOLDL_CONS THENC RATOR_CONV (RAND_CONV (eval n)) THENC
        recurse (n + 1))) t
in
  recurse 0
end

fun foldl_append_CONV d = let
  val core = RAND_CONV (K d) THENC FOLDL_EVAL
in
  REWR_CONV rich_listTheory.FOLDL_APPEND THENC
  RATOR_CONV (RAND_CONV core)
end

fun iterate n defs t = let
  fun recurse m defs th = let
    val t = rhs (concl th)
  in
    if m < 1 orelse null defs then (defs, th)
    else if listSyntax.is_append (rand t) then
      let
        val _ = print (Int.toString (n - m) ^ ": ")
        val th' = time (foldl_append_CONV (hd defs)) (rhs (concl th))
      in
        recurse (m - 1) (tl defs) (TRANS th th')
      end
    else
      let
        val _ = print (Int.toString (n - m) ^ ": ")
        val th' = time (RAND_CONV (K (hd defs)) THENC FOLDL_EVAL)
                       (rhs (concl th))
      in
        (tl defs, TRANS th th')
      end
  end
in
  recurse n defs (REFL t)
end

val FLOOKUP_t = prim_mk_const { Thy = "finite_map", Name = "FLOOKUP"}
val lookup_fmty = #1 (dom_rng (type_of FLOOKUP_t))
fun mk_flookup_eqn fm k =
    EVAL (mk_comb(mk_icomb(FLOOKUP_t, fm), k))

val mk_def = let
  val iref = ref 0
in
  fn t => let
    val i = !iref
    val _ = iref := !iref + 1;
    val nm = "internal" ^ Int.toString (!iref)
  in
    new_definition(nm ^ "_def", mk_eq(mk_var(nm, type_of t), t))
  end
end

(*
val sz = 20
val num = ``:num``
fun genfm 0 = finite_mapSyntax.mk_fempty(num,num)
  | genfm n = finite_mapSyntax.mk_fupdate
               (genfm(n-1),
                pairSyntax.mk_pair(numSyntax.term_of_int n,
                                   numSyntax.term_of_int (n+1)))

val fm = genfm 30
val t = ``foo (bar baz) ^fm x``
*)

val [cond1,cond2] = CONJUNCTS bool_case_thm

fun flookup_fupdate_conv eqconv =
  let
    fun f tm =
      TRY_CONV
        (REWR_CONV FLOOKUP_UPDATE
         THENC (RATOR_CONV(RATOR_CONV(RAND_CONV eqconv)))
         THENC (REWR_CONV cond1 ORELSEC REWR_CONV cond2)
         THENC f)
      tm
  in f
  end

(* TODO: MOVE THIS to Drule *)
  local
     val thms = Drule.CONJUNCTS (Q.SPEC `t` boolTheory.IMP_CLAUSES)
     val T_imp = Drule.GEN_ALL (hd thms)
     val F_imp = Drule.GEN_ALL (List.nth (thms, 2))
     val NT_imp = DECIDE ``(~F ==> t) = t``
     fun dest_neg_occ_var tm1 tm2 =
        case Lib.total boolSyntax.dest_neg tm1 of
           SOME v => if Term.is_var v andalso not (Term.var_occurs v tm2)
                        then SOME v
                     else NONE
         | NONE => NONE
  in
     fun ELIM_UNDISCH thm =
        case Lib.total boolSyntax.dest_imp (Thm.concl thm) of
           SOME (l, r) =>
              if l = boolSyntax.T
                 then Conv.CONV_RULE (Conv.REWR_CONV T_imp) thm
              else if l = boolSyntax.F
                 then Conv.CONV_RULE (Conv.REWR_CONV F_imp) thm
              else if Term.is_var l andalso not (Term.var_occurs l r)
                 then Conv.CONV_RULE (Conv.REWR_CONV T_imp)
                         (Thm.INST [l |-> boolSyntax.T] thm)
              else (case dest_neg_occ_var l r of
                       SOME v => Conv.CONV_RULE (Conv.REWR_CONV NT_imp)
                                    (Thm.INST [v |-> boolSyntax.F] thm)
                     | NONE => Drule.UNDISCH thm)
         | NONE => raise ERR "ELIM_UNDISCH" ""
  end

  (* ---------------------------- *)

  (* Apply rule to hyphothesis tm *)

  fun HYP_RULE r tm = ELIM_UNDISCH o r o Thm.DISCH tm

  (* Apply rule to hyphotheses satisfying P *)

  fun PRED_HYP_RULE r P thm =
     List.foldl (Lib.uncurry (HYP_RULE r)) thm (List.filter P (Thm.hyp thm))

  (* Apply conversion c to all hyphotheses *)

  fun ALL_HYP_RULE r = PRED_HYP_RULE r (K true)
  local
     fun LAND_RULE c = Conv.CONV_RULE (Conv.LAND_CONV c)
  in
     fun HYP_CONV_RULE c = HYP_RULE (LAND_RULE c)
     fun PRED_HYP_CONV_RULE c = PRED_HYP_RULE (LAND_RULE c)
     fun ALL_HYP_CONV_RULE c = ALL_HYP_RULE (LAND_RULE c)
     fun FULL_CONV_RULE c = ALL_HYP_CONV_RULE c o Conv.CONV_RULE c
  end
(* END TODO *)

(* TODO: MOVE THIS to finite_mapSyntax *)
  val mk_flookup = mk_binop FLOOKUP_t
  val dest_flookup = dest_binop FLOOKUP_t (ERR "dest_flookup" "not an FLOOKUP")
  val is_flookup = can dest_flookup
(* END TODO *)

fun get_flookup_eqns conv hrule th =
  let
    fun f ls th =
      let
        val tm = rhs(concl th)
        val x = rand tm
        val th = CONV_RULE(RAND_CONV(REWR_CONV FLOOKUP_UPDATE)) th
        val r = rhs(concl th)
        val k = r |> rator |> rator |> rand |> lhs
        val eq1 = th
          |> INST [x|->k]
          |> RIGHT_CONV_RULE
               (RATOR_CONV(RATOR_CONV(RAND_CONV conv))
                THENC REWR_CONV cond1)
          |> hrule
        val neq = boolSyntax.mk_neg(boolSyntax.mk_eq(k,x))
        val eq2 = th
          |> RIGHT_CONV_RULE
               (RATOR_CONV(RATOR_CONV(RAND_CONV(PURE_ONCE_REWRITE_CONV[ASSUME neq])))
                THENC (REWR_CONV cond2))
      in
        f (eq1::ls) eq2
      end
      handle HOL_ERR _ => ls
  in
    f [] th
  end

fun extract_fmap sz conv hrule t = let
  fun test t = finite_mapSyntax.is_fupdate t andalso lbinop_size 0 t > sz
  val fm = find_term test t
  val ty = type_of fm
  val lookup_t = inst (match_type lookup_fmty ty) FLOOKUP_t
  val def = mk_def fm
  val fl_def = AP_TERM lookup_t def
  val domty = hd(snd(dest_type ty))
  val fl_tm = mk_comb(rhs(concl fl_def),genvar domty)
  val fl_th = RATOR_CONV(RAND_CONV(REWR_CONV(SYM def))) fl_tm
  val eqns = get_flookup_eqns conv hrule (SYM fl_th)
  val deftm = lhs(concl def)
  fun fl_conv tm =
    if same_const (rand(rator tm)) deftm
      then PURE_ONCE_REWRITE_CONV eqns tm
    else raise ERR "" ""
in
  (ONCE_DEPTH_CONV (REWR_CONV (SYM def)) t, (lookup_t,2,fl_conv), def)
end

val numeq_rws = [
  REFL_CLAUSE, CONJUNCT2 NOT_CLAUSES,
  arithmeticTheory.NUMERAL_DEF,
  numeralTheory.numeral_eq,
  GSYM arithmeticTheory.ALT_ZERO]
val numeq_conv = PURE_REWRITE_CONV numeq_rws

val coneq_conv = PURE_ONCE_REWRITE_CONV (#rewrs(TypeBase.simpls_of``:string id option``))
                 THENC PURE_ONCE_REWRITE_CONV (#rewrs(TypeBase.simpls_of``:string id``))
                 THENC ONCE_DEPTH_CONV string_EQ_CONV
                 THENC PURE_REWRITE_CONV [REFL_CLAUSE, CONJUNCT2 NOT_CLAUSES, AND_CLAUSES]

fun doit i (defs, th) = let
  val list_t = rand (rhs (concl th))
  val nstr = listSyntax.mk_length list_t |> (PURE_REWRITE_CONV defs THENC EVAL)
               |> concl |> rhs |> term_to_string
  val _ = print (nstr^" declarations still to go\n")
  val (defs', th20_0) = iterate i defs (rhs (concl th))
  val th20 = CONV_RULE (RAND_CONV (K th20_0)) th
  val _ = PolyML.fullGC()
in
  (defs', th20)
end

end
