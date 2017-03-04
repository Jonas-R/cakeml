open preamble mlstringTheory cfHeapsBaseTheory

val _ = new_theory"rofsFFI"

(* TODO: put these calls in a re-usable option syntax Lib *)
val _ = monadsyntax.temp_add_monadsyntax();
val _ = temp_overload_on ("return", ``SOME``)
val _ = temp_overload_on ("fail", ``NONE``)
val _ = temp_overload_on ("SOME", ``SOME``)
val _ = temp_overload_on ("NONE", ``NONE``)
val _ = temp_overload_on ("monad_bind", ``OPTION_BIND``)
val _ = temp_overload_on ("monad_unitbind", ``OPTION_IGNORE_BIND``)
(* -- *)

val _ = Datatype`
  RO_fs = <| files : (mlstring # char list) list ;
             infds : (num # (mlstring # num)) list |>
`

val wfFS_def = Define`
  wfFS fs =
    ∀fd. fd ∈ FDOM (alist_to_fmap fs.infds) ⇒
         fd < 255 ∧
         ∃fnm off. ALOOKUP fs.infds fd = SOME (fnm,off) ∧
                   fnm ∈ FDOM (alist_to_fmap fs.files)
`;

val wfFS_DELKEY = Q.store_thm(
  "wfFS_DELKEY[simp]",
  `wfFS fs ⇒ wfFS (fs with infds updated_by A_DELKEY k)`,
  simp[wfFS_def, MEM_MAP, PULL_EXISTS, FORALL_PROD, EXISTS_PROD,
       ALOOKUP_ADELKEY] >> metis_tac[]);

val nextFD_def = Define`
  nextFD fsys = LEAST n. ~ MEM n (MAP FST fsys.infds)
`;

val nextFD_ltX = Q.store_thm(
  "nextFD_ltX",
  `CARD (set (MAP FST fs.infds)) < x ⇒ nextFD fs < x`,
  simp[nextFD_def] >> strip_tac >> numLib.LEAST_ELIM_TAC >> simp[] >>
  qabbrev_tac `ns = MAP FST fs.infds` >> RM_ALL_ABBREVS_TAC >> conj_tac
  >- (qexists_tac `MAX_SET (set ns) + 1` >>
      pop_assum kall_tac >> DEEP_INTRO_TAC MAX_SET_ELIM >> simp[] >>
      rpt strip_tac >> res_tac >> fs[]) >>
  rpt strip_tac >> spose_not_then assume_tac >>
  `count x ⊆ set ns` by simp[SUBSET_DEF] >>
  `x ≤ CARD (set ns)`
     by metis_tac[CARD_COUNT, CARD_SUBSET, FINITE_LIST_TO_SET] >>
  fs[]);

val nextFD_NOT_MEM = Q.store_thm(
  "nextFD_NOT_MEM",
  `∀f n fs. ¬MEM (nextFD fs,f,n) fs.infds`,
  rpt gen_tac >> simp[nextFD_def] >> numLib.LEAST_ELIM_TAC >> conj_tac
  >- (qexists_tac `MAX_SET (set (MAP FST fs.infds)) + 1` >>
      DEEP_INTRO_TAC MAX_SET_ELIM >>
      simp[MEM_MAP, EXISTS_PROD, FORALL_PROD] >> rw[] >> strip_tac >>
      res_tac >> fs[]) >>
  simp[EXISTS_PROD, FORALL_PROD, MEM_MAP]);

val openFile_def = Define`
  openFile fnm fsys =
     let fd = nextFD fsys
     in
       do
          assert (fd < 255) ;
          ALOOKUP fsys.files fnm ;
          return (fd, fsys with infds := (nextFD fsys, (fnm, 0)) :: fsys.infds)
       od
`;

val openFileFS_def = Define`
  openFileFS fnm fs =
    case openFile fnm fs of
      NONE => fs
    | SOME (_, fs') => fs'
`;

val wfFS_openFile = Q.store_thm(
  "wfFS_openFile",
  `wfFS fs ⇒ wfFS (openFileFS fnm fs)`,
  simp[openFileFS_def, openFile_def] >>
  Cases_on `nextFD fs < 255` >> simp[] >>
  Cases_on `ALOOKUP fs.files fnm` >> simp[] >>
  dsimp[wfFS_def, MEM_MAP, EXISTS_PROD, FORALL_PROD] >> rw[] >>
  metis_tac[ALOOKUP_EXISTS_IFF]);

val eof_def = Define`
  eof fd fsys =
    do
      (fnm,pos) <- ALOOKUP fsys.infds fd ;
      contents <- ALOOKUP fsys.files fnm ;
      return (LENGTH contents <= pos)
    od
`;

val validFD_def = Define`
  validFD fd fs ⇔ fd ∈ FDOM (alist_to_fmap fs.infds)
`;

val wfFS_eof_EQ_SOME = Q.store_thm(
  "wfFS_eof_EQ_SOME",
  `wfFS fs ∧ validFD fd fs ⇒
   ∃b. eof fd fs = SOME b`,
  simp[eof_def, EXISTS_PROD, PULL_EXISTS, MEM_MAP, wfFS_def, validFD_def] >>
  rpt strip_tac >> res_tac >> metis_tac[ALOOKUP_EXISTS_IFF]);

val FDchar_def = Define`
  FDchar fd fs =
    do
      (fnm, off) <- ALOOKUP fs.infds fd ;
      content <- ALOOKUP fs.files fnm ;
      if off < LENGTH content then SOME (EL off content)
      else NONE
    od
`;

val eof_FDchar = Q.store_thm(
  "eof_FDchar",
  `eof fd fs = SOME T ⇒ FDchar fd fs = NONE`,
  simp[eof_def, EXISTS_PROD, FDchar_def, PULL_EXISTS]);

val bumpFD_def = Define`
  bumpFD fd fs =
    case FDchar fd fs of
        NONE => fs
      | SOME _ =>
          fs with infds updated_by (ALIST_FUPDKEY fd (I ## SUC))
`;

val eof_bumpFD = Q.store_thm(
  "eof_bumpFD",
  `eof fd fs = SOME T ⇒ bumpFD fd fs = fs`,
  simp[bumpFD_def, eof_FDchar]);

val neof_FDchar = Q.store_thm(
  "neof_FDchar",
  `eof fd fs = SOME F ⇒ ∃c. FDchar fd fs = SOME c`,
  simp[eof_def, FDchar_def, EXISTS_PROD, PULL_EXISTS, FORALL_PROD]);

val option_case_eq =
    prove_case_eq_thm  { nchotomy = option_nchotomy, case_def = option_case_def}

val wfFS_bumpFD = Q.store_thm(
  "wfFS_bumpFD[simp]",
  `wfFS (bumpFD fd fs) ⇔ wfFS fs`,
  simp[bumpFD_def] >> Cases_on `FDchar fd fs` >> simp[] >>
  dsimp[wfFS_def, ALIST_FUPDKEY_ALOOKUP, option_case_eq, bool_case_eq,
        EXISTS_PROD] >> metis_tac[]);

val fgetc_def = Define`
  fgetc fd fsys =
    if validFD fd fsys then SOME (FDchar fd fsys, bumpFD fd fsys)
    else NONE
`;

val closeFD_def = Define`
  closeFD fd fsys =
    do
       ALOOKUP fsys.infds fd ;
       return ((), fsys with infds := A_DELKEY fd fsys.infds)
    od
`;

val inFS_fname_def = Define `
  inFS_fname s fs = (s ∈ FDOM (alist_to_fmap fs.files))`

val not_inFS_fname_openFile = Q.store_thm(
  "not_inFS_fname_openFile",
  `~inFS_fname fname fs ⇒ openFile fname fs = NONE`,
  fs [inFS_fname_def, openFile_def, ALOOKUP_NONE]);

val inFS_fname_ALOOKUP_EXISTS = Q.store_thm(
  "inFS_fname_ALOOKUP_EXISTS",
  `inFS_fname fname fs ⇒ ∃content. ALOOKUP fs.files fname = SOME content`,
  fs [inFS_fname_def, MEM_MAP] >> rpt strip_tac >> fs[] >>
  rename1 `fname = FST p` >> Cases_on `p` >>
  fs[ALOOKUP_EXISTS_IFF] >> metis_tac[]);

val ALOOKUP_SOME_inFS_fname = Q.store_thm(
  "ALOOKUP_SOME_inFS_fname",
  `ALOOKUP fs.files fnm = SOME contents ==> inFS_fname fnm fs`,
  Induct_on `fs.files` >> rpt strip_tac >>
  qpat_x_assum `_ = fs.files` (assume_tac o GSYM) >> rw[] >>
  fs [inFS_fname_def] >> rename1 `fs.files = p::ps` >>
  Cases_on `p` >> fs [ALOOKUP_def] >> every_case_tac >> fs[] >> rw[] >>
  first_assum (qspec_then `fs with files := ps` assume_tac) >> fs []
);

(* ----------------------------------------------------------------------
    Coding RO_fs values as ffi values
   ---------------------------------------------------------------------- *)

val encode_files_def = Define`
  encode_files fs = encode_list (encode_pair (Str o explode) Str) fs
`;

val encode_fds_def = Define`
  encode_fds fds =
     encode_list (encode_pair Num (encode_pair (Str o explode) Num)) fds
`;

val encode_def = zDefine`
  encode fs = cfHeapsBase$Cons
                         (encode_files fs.files)
                         (encode_fds fs.infds)
`


val decode_files_def = Define`
  decode_files f = decode_list (decode_pair (lift implode o destStr) destStr) f
`

val decode_encode_files = Q.store_thm(
  "decode_encode_files",
  `∀l. decode_files (encode_files l) = return l`,
  rw[encode_files_def, decode_files_def] >>
  match_mp_tac decode_encode_list >>
  match_mp_tac decode_encode_pair >>
  rw[implode_explode,MAP_MAP_o,ORD_CHR,MAP_EQ_ID] >>
  Q.ISPEC_THEN`x`mp_tac w2n_lt \\ rw[]);

val decode_fds_def = Define`
  decode_fds =
    decode_list (decode_pair destNum
                             (decode_pair (lift implode o destStr) destNum))
`;

val decode_encode_fds = Q.store_thm(
  "decode_encode_fds",
  `decode_fds (encode_fds fds) = return fds`,
  simp[decode_fds_def, encode_fds_def] >>
  simp[decode_encode_list, decode_encode_pair, implode_explode]);

val decode_def = zDefine`
  (decode (Cons files0 fds0) =
     do
        files <- decode_files files0 ;
        fds <- decode_fds fds0 ;
        return <| files := files ; infds := fds |>
     od) ∧
  (decode _ = fail)
`;

val decode_encode_FS = Q.store_thm(
  "decode_encode_FS[simp]",
  `decode (encode fs) = return fs`,
  simp[decode_def, encode_def, decode_encode_files, decode_encode_fds] >>
  simp[theorem "RO_fs_component_equality"]);

val encode_11 = Q.store_thm(
  "encode_11[simp]",
  `encode fs1 = encode fs2 ⇔ fs1 = fs2`,
  metis_tac[decode_encode_FS, SOME_11]);

(* ----------------------------------------------------------------------
    Making the above available as FFI functions
   ----------------------------------------------------------------------

    There are four operations to be used in the example:

    1. write char to stdout
    2. open file
    3. read char from file descriptor
    4. close file

   ---------------------------------------------------------------------- *)

val getNullTermStr_def = Define`
  getNullTermStr (bytes : word8 list) =
     let sz = findi 0w bytes
     in
       if sz = LENGTH bytes then NONE
       else SOME(MAP (CHR o w2n) (TAKE sz bytes))
`
val ffi_open_def = Define`
  ffi_open bytes fs =
    do
      fname <- getNullTermStr bytes;
      (fd, fs') <- openFile (implode fname) fs;
      assert(fd < 255);
      return (LUPDATE (n2w fd) 0 bytes, fs')
    od ++
    return (LUPDATE 255w 0 bytes, fs)`;

val ffi_fgetc_def = Define`
  ffi_fgetc bytes fs =
    do
      assert(LENGTH bytes = 1);
      (copt, fs') <- fgetc (w2n (HD bytes)) fs;
      case copt of
      | NONE => return ([255w], fs')
      | SOME c => return ([n2w (ORD c)], fs')
    od`;

val ffi_close_def = Define`
  ffi_close bytes fs =
    do
      assert(LENGTH bytes = 1);
      do
        (_, fs') <- closeFD (w2n (HD bytes)) fs;
        return (LUPDATE 1w 0 bytes, fs')
      od ++
      return (LUPDATE 0w 0 bytes, fs)
    od`;

val ffi_isEof_def = Define`
  ffi_isEof bytes fs =
    do
      assert(LENGTH bytes = 1);
      do
        b <- eof (w2n (HD bytes)) fs ;
        return (LUPDATE (if b then 1w else 0w) 0 bytes, fs)
      od ++
      return (LUPDATE 255w 0 bytes, fs)
    od`;

val rofs_ffi_part_def = Define`
  rofs_ffi_part =
    (encode,decode,
      [("open",ffi_open);
       ("fgetc",ffi_fgetc);
       ("close",ffi_close);
       ("isEof",ffi_isEof)])`;

val ffi_open_length = Q.store_thm("ffi_open_length",
  `ffi_open bytes fs = SOME (bytes',fs') ==> LENGTH bytes' = LENGTH bytes`,
  rw[ffi_open_def]
  \\ Cases_on`getNullTermStr bytes` \\ fs[] \\ rw[]
  \\ Cases_on`openFile (implode x) fs` \\ fs[] \\ rw[]
  \\ pairarg_tac \\ fs[]
  \\ Cases_on`fd < 255` \\ fs[] \\ rw[]);

val ffi_fgetc_length = Q.store_thm("ffi_fgetc_length",
  `ffi_fgetc bytes fs = SOME (bytes',fs') ==> LENGTH bytes' = LENGTH bytes`,
  EVAL_TAC \\ rw[] \\ every_case_tac \\ fs[] \\ rw[]);

val ffi_close_length = Q.store_thm("ffi_close_length",
  `ffi_close bytes fs = SOME (bytes',fs') ==> LENGTH bytes' = LENGTH bytes`,
  rw[ffi_close_def]
  \\ Cases_on`closeFD (w2n (HD bytes)) fs` \\ fs[] \\ rw[]
  \\ pairarg_tac \\ fs[] \\ rw[]);

val ffi_isEof_length = Q.store_thm("ffi_isEof_length",
  `ffi_isEof bytes fs = SOME (bytes',fs') ==> LENGTH bytes' = LENGTH bytes`,
  rw[ffi_isEof_def]
  \\ Cases_on`eof (w2n (HD bytes)) fs` \\ fs[] \\ rw[]);

(* insert null-terminated-string (l1) at specified index (n) in a list (l2) *)
val insertNTS_atI_def = Define`
  insertNTS_atI (l1:word8 list) n l2 =
    TAKE n l2 ++ l1 ++ [0w] ++ DROP (n + LENGTH l1 + 1) l2
`;

val insertNTS_atI_NIL = Q.store_thm(
  "insertNTS_atI_NIL",
  `∀n l. n < LENGTH l ==> insertNTS_atI [] n l = LUPDATE 0w n l`,
  simp[insertNTS_atI_def] >> Induct_on `n`
  >- (Cases_on `l` >> simp[LUPDATE_def]) >>
  Cases_on `l` >> simp[LUPDATE_def, ADD1]);

val insertNTS_atI_CONS = Q.store_thm(
  "insertNTS_atI_CONS",
  `∀n l h t.
     n + LENGTH t + 1 < LENGTH l ==>
     insertNTS_atI (h::t) n l = LUPDATE h n (insertNTS_atI t (n + 1) l)`,
  simp[insertNTS_atI_def] >> Induct_on `n`
  >- (Cases_on `l` >> simp[ADD1, LUPDATE_def]) >>
  Cases_on `l` >> simp[ADD1] >> fs[ADD1] >>
  simp[GSYM ADD1, LUPDATE_def]);

val LUPDATE_insertNTS_commute = Q.store_thm(
  "LUPDATE_insertNTS_commute",
  `∀ws pos1 pos2 a w.
     pos2 < pos1 ∧ pos1 + LENGTH ws < LENGTH a
       ⇒
     insertNTS_atI ws pos1 (LUPDATE w pos2 a) =
       LUPDATE w pos2 (insertNTS_atI ws pos1 a)`,
  Induct >> simp[insertNTS_atI_NIL, insertNTS_atI_CONS, LUPDATE_commutes]);

val getNullTermStr_insertNTS_atI = Q.store_thm(
  "getNullTermStr_insertNTS_atI",
  `∀cs l. LENGTH cs < LENGTH l ∧ ¬MEM 0w cs ⇒
          getNullTermStr (insertNTS_atI cs 0 l) = SOME (MAP (CHR o w2n) cs)`,
  simp[getNullTermStr_def, insertNTS_atI_def, findi_APPEND, NOT_MEM_findi,
       findi_def, TAKE_APPEND])

val LENGTH_insertNTS_atI = Q.store_thm(
  "LENGTH_insertNTS_atI",
  `p + LENGTH l1 < LENGTH l2 ⇒ LENGTH (insertNTS_atI l1 p l2) = LENGTH l2`,
  simp[insertNTS_atI_def]);

val _ = export_theory();