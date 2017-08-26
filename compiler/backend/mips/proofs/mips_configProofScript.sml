open preamble backendProofTheory
     mips_configTheory mips_targetProofTheory
open blastLib;

val _ = new_theory"mips_configProof";

val is_mips_machine_config_def = Define`
  is_mips_machine_config mc ⇔
  mc.target = mips_target ∧
  mc.len_reg =5  ∧
  mc.ptr_reg = 4 ∧
  mc.callee_saved_regs = [21;22;23]`;

val names_tac =
  simp[tlookup_bij_iff] \\ EVAL_TAC
  \\ REWRITE_TAC[SUBSET_DEF] \\ EVAL_TAC
  \\ rpt strip_tac \\ rveq \\ EVAL_TAC

val mips_backend_config_ok = Q.store_thm("mips_backend_config_ok",`
  backend_config_ok mips_backend_config`,
  simp[backend_config_ok_def]>>rw[]>>TRY(EVAL_TAC>>NO_TAC)
  >- fs[mips_backend_config_def]
  >- (EVAL_TAC>> blastLib.FULL_BBLAST_TAC)
  >- names_tac
  >- (
    fs [stack_removeTheory.store_offset_def,
        stack_removeTheory.store_pos_def]
    \\ every_case_tac \\ fs [] THEN1 EVAL_TAC
    \\ fs [stack_removeTheory.store_list_def]
    \\ fs [INDEX_FIND_CONS_EQ_SOME,EVAL ``INDEX_FIND n f []``]
    \\ rveq \\ fs [] \\ EVAL_TAC)
  \\ fs[stack_removeTheory.max_stack_alloc_def]
  \\ EVAL_TAC>>fs[]
  \\ match_mp_tac bitTheory.NOT_BIT_GT_TWOEXP
  \\ fs[])

val mips_machine_config_ok = Q.store_thm("mips_machine_config_ok",
  `is_mips_machine_config mc ⇒ mc_conf_ok mc`,
  rw[lab_to_targetProofTheory.mc_conf_ok_def,is_mips_machine_config_def]
  >- EVAL_TAC
  >- simp[mips_targetProofTheory.mips_backend_correct]
  >- EVAL_TAC
  >- EVAL_TAC
  >- EVAL_TAC
  >- metis_tac[asmPropsTheory.backend_correct_def,asmPropsTheory.target_ok_def,mips_backend_correct]);

val mips_init_ok = Q.store_thm("mips_init_ok",
  `is_mips_machine_config mc ⇒
    mc_init_ok mips_backend_config mc`,
  rw[mc_init_ok_def] \\
  fs[is_mips_machine_config_def] \\
  EVAL_TAC);

val is_mips_machine_config_mc = mips_init_ok |> concl |> dest_imp |> #1

val mips_compile_correct =
  compile_correct
  |> Q.GENL[`c`,`mc`]
  |> Q.ISPECL[`mips_backend_config`, `^(rand is_mips_machine_config_mc)`]
  |> ADD_ASSUM is_mips_machine_config_mc
  |> SIMP_RULE (srw_ss()) [mips_backend_config_ok,UNDISCH mips_machine_config_ok,UNDISCH mips_init_ok]
  |> CONV_RULE (ONCE_DEPTH_CONV(EVAL o (assert(same_const``heap_regs``o fst o strip_comb))))
  |> DISCH_ALL
  |> curry save_thm"mips_compile_correct";

val _ = export_theory();
