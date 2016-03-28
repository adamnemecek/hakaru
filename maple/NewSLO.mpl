# Teach Maple (through depends and eval) about our new binding forms.
# Integrand, LO, and lam bind from 1st arg to 2nd arg.
# Branch binds from 1st arg (a pattern) to 2nd arg.
# Bind and ary bind from 2nd arg to 3rd arg.

`depends/Integrand` := proc(v, e, x) depends(e, x minus {v}) end proc:
`depends/LO`        := proc(v, e, x) depends(e, x minus {v}) end proc:
`depends/lam`       := proc(v, e, x) depends(e, x minus {v}) end proc:

`depends/Branch`    := proc(p, e, x) depends(e, x minus {pattern_binds(p)}) end proc:
pattern_binds := proc(p)
  if p = PWild or p = PDone then
    NULL
  elif p :: PVar(anything) then
    op(1,p)
  elif p :: PDatum(anything, anything) then
    pattern_binds(op(2,p))
  elif p :: {PInl(anything), PInr(anything),
             PKonst(anything), PIdent(anything)} then
    pattern_binds(op(1,p))
  elif p :: PEt(anything, anything) then
    pattern_binds(op(1,p)), pattern_binds(op(2,p))
  else
    error "pattern_binds: %1 is not a pattern", p
  end if
end proc:

# note that v _can_ occur in m1.
`depends/Bind` := proc(m1, v::name, m2, x)
  depends(m1, x) or depends(m2, x minus {v})
end proc:

# note that i _can_ occur in n.
`depends/ary` := proc(n, i::name, e, x)
  depends(n, x) or depends(e, x minus {i})
end proc:

generic_evalat := proc(vv::{name,list(name)}, mm, eqs)
  local v, m, eqsRemain, subsEq, eq, rename, funs;
  funs := map2(op, 0, indets(mm, 'function'));
  eqsRemain := remove((eq -> op(1,eq) = op(2,eq)), eqs);
  eqsRemain, subsEq := selectremove((eq -> type(op(1,eq), 'name')), eqsRemain);
  eqsRemain := select((eq -> not has(op(1,eq), vv) and
    (depends(mm, op(1,eq)) or member(op(1,eq), funs))), eqsRemain);
  m := mm;
  rename := proc(v::name)
    local vRename;
    if depends(eqsRemain, v) then
      vRename := gensym(v);
      m := subs(v=vRename, m);
      vRename
    else
      v
    end if
  end proc;
  if vv :: name then
    v := rename(vv)
  else
    v := map(rename, vv);
  end if;
  m := subs(subsEq,m);
  if nops(eqsRemain) > 0 then
    m := eval(m,eqsRemain);
  end if;
  v, m;
end proc:

`eval/Integrand` := proc(e, eqs)
  local v, ee;
  v, ee := op(e);
  eval(op(0,e), eqs)(generic_evalat(v, ee, eqs))
end proc:

`eval/LO` := proc(e, eqs)
  local v, ee;
  v, ee := op(e);
  eval(op(0,e), eqs)(generic_evalat(v, ee, eqs))
end proc:

`eval/lam` := proc(e, eqs)
  local v, ee;
  v, ee := op(e);
  eval(op(0,e), eqs)(generic_evalat(v, ee, eqs))
end proc:

`eval/Branch` := proc(e, eqs)
  local p, ee, vBefore, vAfter;
  p, ee := op(e);
  vBefore := [pattern_binds(p)];
  vAfter, ee := generic_evalat(vBefore, ee, eqs);
  eval(op(0,e), eqs)(subs(op(zip(`=`, vBefore, vAfter)), p), ee)
end proc:

`eval/Bind` := proc(e, eqs)
  local m1, v, m2;
  m1, v, m2 := op(e);
  eval(op(0,e), eqs)(eval(m1, eqs), generic_evalat(v, m2, eqs))
end proc:

`eval/ary` := proc(e, eqs)
  local n, i, ee;
  n, i, ee := op(e);
  eval(op(0,e), eqs)(eval(n, eqs), generic_evalat(i, ee, eqs))
end proc:

#############################################################################

foldr_piecewise := proc(cons, nil, pw) # pw may or may not be piecewise
  # View pw as a piecewise and foldr over its arms
  if pw :: specfunc(piecewise) then
    foldr(proc(i,x) cons(op(i,pw), op(i+1,pw), x) end proc,
          `if`(nops(pw)::odd, cons(true, op(-1,pw), nil), nil),
          seq(1..nops(pw)-1, 2))
  else
    cons(true, pw, nil)
  end if
end proc;

#############################################################################

# make gensym global, so that it can be shared with other 'global' routines
gensym := module()
  export ModuleApply;
  local gs_counter, utf8, blocks, radix, unicode;
  gs_counter := -1;
  utf8 := proc(n :: integer)
    local m;
    if n<128 then n
    elif n<2048 then 192+iquo(n,64,'m'), 128+m
    elif n<65536 then 224+iquo(n,4096,'m'), 128+iquo(m,64,'m'), 128+m
    elif n<2097152 then 240+iquo(n,262144,'m'), 128+iquo(m,4096,'m'), 128+iquo(m,64,'m'), 128+m
    elif n<67108864 then 248+iquo(n,16777216,'m'), 128+iquo(m,262144,'m'), 128+iquo(m,4096,'m'), 128+iquo(m,64,'m'), 128+m
    elif n<2147483648 then 248+iquo(n,1073741824,'m'), 128+iquo(m,16777216,'m'), 128+iquo(m,262144,'m'), 128+iquo(m,4096,'m'), 128+iquo(m,64,'m'), 128+m
    end if
  end proc;
  blocks := map((b -> block(convert(op(0,b), decimal, hex), op(1,b))),
                ["4e00"(20950)]);
  radix := `+`(op(map2(op, 2, blocks))) / 2;
  unicode := proc(nn)
    local n, b;
    n := nn;
    for b in blocks do
      if n < op(2,b) then return n + op(1,b) else n := n - op(2,b) end if
    end do
  end proc;
  ModuleApply := proc(x::name)
    gs_counter := gs_counter + 1;
    cat(x, op(map(StringTools:-Char, map(utf8 @ unicode, applyop(`+`, 1, map(`*`, convert(gs_counter, 'base', radix), 2), 1)))))
  end proc;
end module: # gensym

#############################################################################

KB := module ()
  option package;
  local KB, Introduce, Constrain,
        assert_deny, coalesce_bounds, htype_to_property,
        myexpand_product,
        ModuleLoad, ModuleUnload;
  export empty, genLebesgue, genType, assert,
         kb_subtract, simplify_assuming, kb_to_assumptions,
         htype_patterns;
  global t_kb, t_type, Bound,
         AlmostEveryReal, HReal, HInt, HData, HMeasure, HArray, HFunction,
         DatumStruct, Konst, Ident;

  empty := KB();

  genLebesgue := proc(xx::name, lo, hi, kb::t_kb)
    # The value of a variable created using genLebesgue is respected only up to
    # negligible changes
    genType(xx, AlmostEveryReal(Bound(`>`,lo), Bound(`<`,hi)), kb, _rest)
  end proc;

  genType := proc(xx::name, t::t_type, kb::t_kb)
    # A variable created using genType is a parameter, in the sense that its
    # value is completely respected
    local x;
    x := `if`(depends([t,kb,_rest], xx), gensym(xx), xx);
    x, KB(Introduce(x, t), op(kb));
  end proc;

  assert := proc(b, kb::t_kb) assert_deny(b, true, kb) end proc;

  assert_deny := proc(bb, pol::identical(true,false), kb::t_kb)
    # Add `if`(pol,bb,Not(bb)) to kb and return the resulting KB.
    local as, b, log_b, k, x, rel, e, c, y;
    if bb = pol then
      # Ignore literal true and Not(false).
      kb
    elif bb :: `if`(pol, {specfunc(anything, And), `and`},
                         {specfunc(anything, Or ), `or` }) then
      foldr(((b,kb) -> assert_deny(b, pol, kb)), kb, op(bb))
    elif bb :: {specfunc(anything, Not), `not`} then
      foldr(((b,kb) -> assert_deny(b, not pol, kb)), kb, op(bb))
    else
      as := kb_to_assumptions(kb);
      b := simplify(bb) assuming op(as);
      # Reduce (in)equality between exp(a) and exp(b) to between a and b.
      do
        try log_b := map(ln, b) assuming op(as); catch: break; end try;
        if length(log_b) < length(b)
           and (andmap(is, log_b, real) assuming op(as)) then
          b := log_b;
        else
          break;
        end if;
      end do;
      # Look through kb for the innermost scope where b makes sense.
      k := select((k -> k :: Introduce(name, anything) and depends(b, op(1,k))),
                  kb);
      if nops(k) > 0 then
        x, k := op(op(1,k));
        # Found the innermost scope where b makes sense.
        if b :: And(Or(`<`, `<=`),
                    Or(anyop(identical(x), freeof(x)),
                       anyop(freeof(x), identical(x)))) then
          # b is a bound on x, so compare it against the current bound on x.
          # First, express `if`(pol,b,Not(b)) as rel(x,e)
          rel := op(0,b);
          if x = lhs(b) then
            e := rhs(b);
          else#x=rhs(b)
            e := lhs(b);
            rel := subs({`<`=`>`, `<=`=`>=`}, rel);
          end if;
          if not pol then
            rel := subs({`<`=`>=`, `<=`=`>`, `>`=`<=`, `>=`=`<`}, rel);
          end if;
          if k :: specfunc(AlmostEveryReal) then
            rel := subs({`<=`=`<`, `>=`=`>`}, rel);
          end if;
          # Second, look up the current bound on x, if any.
          c := `if`(rel in {`>`, `>=`}, identical(`>`, `>=`), identical(`<`, `<=`));
          c := [op(map2(subsop, 1=NULL,
                   select(type, kb, Bound(identical(x), c, anything)))),
                op(select(type, k , Bound(              c, anything)) )];
          # Compare the new bound rel        (x,e          )
          # against the old bound op([1,1],c)(x,op([1,2],c))
          if nops(c)>0
            and (is(rel(y,e)) assuming op([1,1],c)(y,op([1,2],c)),
                   y::htype_to_property(k), op(as)) then
            # The old bound renders the new bound superfluous.
            return kb
          elif nops(c)=0
            or (is(op([1,1],c)(y,op([1,2],c))) assuming rel(y,e),
                  y::htype_to_property(k), op(as)) then
            # The new bound supersedes the old bound.
            return KB(Bound(x,rel,e), op(kb))
          end if
        else
          # Try to make b about x using convert/piecewise.
          try
            c := convert(piecewise(b, true, false), 'piecewise', x)
              assuming op(as);
            if c :: specfunc(boolean, piecewise) then
              c := foldr_piecewise(
                     proc(cond, th, el)
                       # cond and th or not cond and el
                       local a, o, n;
                       a := (x,y)-> `if`(x=true,y, `if`(x=false,x,
                                    `if`(y=true,x, `if`(y=false,y, And(x,y)))));
                       o := (x,y)-> `if`(x=false,y, `if`(x=true,x,
                                    `if`(y=false,x, `if`(y=true,y, Or (x,y)))));
                       n := x    -> `if`(x=false,true,
                                    `if`(x=true,false,             Not(x)));
                       o(a(cond,th), a(n(cond),el));
                     end proc,
                     false,
                     c);
            end if
          catch: c := b;
          end try;
          if c <> b then return assert_deny(c, pol, kb) end if
        end if
      end if;
      # Normalize `=` and `<>` constraints a bit.
      if not pol then
        # Negate b
        if   b :: `=`  then b := `<>`(op(b))
        elif b :: `<>` then b := `=` (op(b))
        else b := Not(b) end if
      end if;
      if b :: (anything=name) then b := (rhs(b)=lhs(b)) end if;
      # Add constraint to KB.
      KB(Constrain(b), op(kb))
    end if
  end proc:

  kb_subtract := proc(kb::t_kb, kb0::t_kb)
    local cut;
    cut := nops(kb) - nops(kb0);
    if cut < 0 or KB(op(cut+1..-1, kb)) <> kb0 then
      error "%1 is not an extension of %2", kb, kb0;
    end if;
    map(proc(k)
      local x, t;
      if k :: Introduce(name, anything) then
        x, t := op(k);
        if t :: specfunc(AlmostEveryReal) then
          [genLebesgue, x,
           op([1,2], select(type, t, Bound(identical(`>`), anything))),
           op([1,2], select(type, t, Bound(identical(`<`), anything)))]
        else
          [genType, x, t]
        end if
      elif k :: Bound(name, anything, anything) then
        [assert, op(2,k)(op(1,k),op(3,k))]
      elif k :: Constrain(anything) then
        [assert, op(1,k)]
      end if
    end proc, [op(coalesce_bounds(KB(op(1..cut, kb))))])
  end proc;

  coalesce_bounds := proc(kb::t_kb)
    local t_intro, t_lo, t_hi, lo, hi, rest, k, x, t, b, s, r;
    t_intro := 'Introduce(name, specfunc({AlmostEveryReal,HReal,HInt}))';
    t_lo    := 'identical(`>`,`>=`)';
    t_hi    := 'identical(`<`,`<=`)';
    for k in select(type, kb, t_intro) do
      x, t := op(k);
      b, t := selectremove(type, t, Bound(t_lo, anything));
      if nops(b) > 0 then lo[x] := op(1,b) end if;
      b, t := selectremove(type, t, Bound(t_hi, anything));
      if nops(b) > 0 then hi[x] := op(1,b) end if;
      rest[x] := [op(t)];
    end do;
    for k in select(type, kb, Bound(name, t_lo, anything)) do
      lo[op(1,k)] := subsop(1=NULL,k);
    end do;
    for k in select(type, kb, Bound(name, t_hi, anything)) do
      hi[op(1,k)] := subsop(1=NULL,k);
    end do;
    map(proc(k)
      if k :: t_intro then
        x := op(1,k);
        subsop(2=op([2,0],k)(op(select(type, [lo[x], hi[x]], specfunc(Bound))),
                             op(rest[x])),
               k);
      elif k :: Bound(name, anything, anything) and rest[op(1,k)] :: list then
        NULL;
      else
        k;
      end if;
    end proc, kb);
  end proc;

  simplify_assuming := proc(ee, kb::t_kb)
    local e;
    e := evalindets(ee, 'specfunc({%product, product})', myexpand_product);
    e := evalindets(e, 'specfunc(sum)', expand);
    e := simplify(e) assuming op(kb_to_assumptions(kb));
    eval(e, exp = expand @ exp);
  end proc;

  myexpand_product := proc(prod)
    local x, p, body, quantifier;
    (body, quantifier) := op(prod);
    x := op(1, quantifier);
    p := proc(e)
      local ee;
      if e :: 'exp(anything)' then
        ee := expand(op(1,e));
        ee := convert(ee, 'list', `+`);
        `*`(op(map(z -> exp(sum(z, quantifier)), ee)));
      elif e :: ('freeof'(x) ^ 'anything') then
        op(1,e) ^ expand(sum(op(2,e), quantifier))
      elif e :: ('anything' ^ 'freeof'(x)) then
        p(op(1,e)) ^ op(2,e)
      else
        product(e, quantifier)
      end if
    end proc;
    `*`(op(map(p, convert(body, list, `*`))));
  end proc;

  kb_to_assumptions := proc(kb)
    local t_intro;
    t_intro := 'Introduce(name, specfunc({AlmostEveryReal,HReal,HInt}))';
    map(proc(k)
      local x;
      if k :: t_intro then
        x := op(1,k);
        (x :: htype_to_property(op(2,k))),
        op(map((b -> op(1,b)(x, op(2,b))), op(2,k)))
      elif k :: Bound(anything, anything, anything) then
        op(2,k)(op(1,k), op(3,k))
      elif k :: Constrain(anything) then
        op(1,k)
      else
        NULL # Maple doesn't understand our other types
      end if
    end proc, [op(coalesce_bounds(kb))])
  end proc;

  htype_to_property := proc(t::t_type)
    if t :: specfunc({AlmostEveryReal, HReal}) then real
    elif t :: specfunc(HInt) then integer
    else TopProp end if
  end proc;

  # Enumerate patterns for a given Hakaru type
  htype_patterns := proc(t::t_type)
    :: specfunc(Branch(anything, list(t_type)), Branches);
    local struct;
    uses StringTools;
    if t :: specfunc(DatumStruct(anything, list(Konst(anything))), HData) then
      foldr(proc(struct,ps) Branches(
              op(map((p -> Branch(PDatum(op(1,struct), PInl(op(1,p))),
                                  op(2,p))),
                     foldr(proc(kt,qs)
                             local p, q;
                             Branches(seq(seq(Branch(PEt(op(1,p),op(1,q)),
                                                     [op(op(2,p)),op(op(2,q))]),
                                              q in qs),
                                          p in htype_patterns(op(1,kt))))
                           end proc,
                           Branches(Branch(PDone, [])), op(op(2,struct))))),
              op(map[3](applyop, PInr, [1,2], ps)))
            end proc,
            Branches(), op(t))
    else
      Branches(Branch(PVar(gensym(convert(LowerCase(op(-1, ["x", op(
                                            `if`(t::function,
                                              select(IsUpper, Explode(op(0,t))),
                                              []))])),
                                          name))),
                      [t]))
    end if
  end proc;

  ModuleLoad := proc()
    TypeTools[AddType](t_type,
      '{specfunc(Bound(identical(`<`,`<=`,`>`,`>=`), anything),
                 {AlmostEveryReal, HReal, HInt}),
        specfunc(DatumStruct(anything, list({Konst(t_type), Ident(t_type)})),
                 HData),
        HMeasure(t_type),
        HArray(t_type),
        HFunction(t_type, t_type)}');
    TypeTools[AddType](t_kb,
      'specfunc({
         Introduce(name, t_type),
         Bound(name, identical(`<`,`<=`,`>`,`>=`), anything),
         Constrain({`::`, boolean, `in`, specfunc(anything,{Or,Not})})
       }, KB)');
  end proc;

  ModuleUnload := proc()
    TypeTools[RemoveType](t_kb);
    TypeTools[RemoveType](t_type);
  end proc;

  ModuleLoad();
end module; # KB

#############################################################################

NewSLO := module ()
  option package;
  local t_pw, t_case, p_true, p_false,
        unweight, factorize, pattern_match, make_piece,
        recognize, get_de, recognize_de, mysolve, Diffop, Recognized,
        reduce,
        reduce_pw, reduce_Int, reduce_wl, reduce_Ints, reduce_prod,
        mk_idx,
        get_indicators,
        reduce_PI, elim_int,
        banish, known_measures,
        piecewise_if, nub_piecewise,
        ModuleLoad, ModuleUnload, verify_measure, pattern_equiv,
        find_vars, find_constraints, interpret, reconstruct, invert, 
        get_var_pos, get_int_pos,
        avoid_capture, change_var, disint2;
  export Simplify,
     # note that these first few are smart constructors (for themselves):
         case, app, idx, integrate, applyintegrand, Datum,
     # while these are "proper functions"
         map_piecewise,
         bind, weight,
         toLO, fromLO, improve,
         RoundTrip, RoundTripLO, RoundTripCLO,
         toCLO, fromCLO, cimprove,
         TestHakaru, TestSimplify, measure, density, bounds,
         unintegrate,
         ReparamDetermined, determined, Reparam, Banish,
         disint;
  # these names are not assigned (and should not be).  But they are
  # used as global names, so document that here.
  global Bind, Weight, Ret, Msum, Integrand, Plate, LO, Indicator, ary,
         Lebesgue, Uniform, Gaussian, Cauchy, BetaD, GammaD, StudentT,
         Context,
         lam,
         Inr, Inl, Et, Done, Konst, Ident,
         Branches, Branch, PWild, PVar, PDatum, PInr, PInl, PEt, PDone, PKonst, PIdent;
  uses KB;

  Simplify := proc(e, t::t_type, kb::t_kb)
    local patterns, x, kb1, ex;
    if t :: HMeasure(anything) then
      fromLO(improve(toLO(e), _ctx=kb), _ctx=kb)
    elif t :: HFunction(anything, anything) then
      patterns := htype_patterns(op(1,t));
      if patterns :: Branches(Branch(PVar(name),anything)) then
        # Eta-expand the function type
        x := `if`(e::lam(name,anything), op(1,e), op([1,1,1],patterns));
        x, kb1 := genType(x, op(1,t), kb, e);
        ex := app(e,x);
        lam(x, Simplify(ex, op(2,t), kb1))
      else
        # Eta-expand the function type and the sum-of-product argument-type
        x := `if`(e::lam(name,anything), op(1,e), d);
        if depends([e,t,kb], x) then x := gensym(x) end if;
        ex := app(e,x);
        lam(x, 'case'(x,
          map(proc(branch)
                local eSubst, pSubst, p1, binds, ys, y, kb1, i, pSubst1;
                eSubst, pSubst := pattern_match([x,e], x, op(1,branch));
                p1 := subs(pSubst, op(1,branch));
                binds := [pattern_binds(p1)];
                ys := [];
                kb1 := kb;
                for i from 1 to nops(binds) do
                  y, kb1 := genType(op(i,binds), op([2,i],branch), kb1);
                  ys := [op(ys), y];
                end do;
                pSubst1 := zip(`=`, binds, ys);
                Branch(subs(pSubst1, p1),
                       Simplify(eval(eval(ex, eSubst), pSubst1), op(2,t), kb1))
              end proc,
              patterns)))
      end if
    else
      simplify_assuming(e, kb)
    end if
  end proc;

  t_pw    := 'specfunc(piecewise)';
  t_case  := 'case(anything, specfunc(Branch(anything, anything), Branches))';
  p_true  := 'PDatum(true,PInl(PDone))';
  p_false := 'PDatum(false,PInr(PInl(PDone)))';

# An integrand h is either an Integrand (our own binding construct for a
# measurable function to be integrated) or something that can be applied
# (probably proc, which should be applied immediately, or a generated symbol).

# TODO evalapply/Integrand instead of applyintegrand?
# TODO evalapply/{Ret,Bind,...} instead of integrate?!

  applyintegrand := proc(h, x)
    if h :: 'Integrand(name, anything)' then
      eval(op(2,h), op(1,h) = x)
    elif h :: procedure then
      h(x)
    else
      'procname(_passed)'
    end if
  end proc;

# Step 1 of 3: from Hakaru to Maple LO (linear operator)

  toLO := proc(m)
    local h;
    h := gensym('h');
    LO(h, integrate(m, h, []))
  end proc;

  # toLO does not use the context, so just map in
  toCLO := proc(c :: Context(t_kb, anything))
    Context(op(1,c), toLO(op(2,c)));
  end proc;

  known_measures := '{Lebesgue(), Uniform(anything, anything),
    Gaussian(anything, anything), Cauchy  (anything, anything),
    StudentT(anything, anything, anything),
    BetaD(anything, anything), GammaD(anything, anything)}':

  integrate := proc(m, h, loops :: list(name = range) := [])
    local x, n, i, res, dens, bds, l;

    if m :: known_measures then
      x := 'xx';
      if h :: 'Integrand(name, anything)' then
        x := op(1,h);
      end if;
      x := gensym(x);
      dens := density[op(0,m)](op(m));
      bds := bounds[op(0,m)](op(m));
      if loops = [] then
        Int(dens(x) * applyintegrand(h, x), x = bds);
      else
        Ints(foldl(product, dens(mk_idx(x,loops)), op(loops))
               * applyintegrand(h, x),
             x, bds, loops)
      end if;
    elif m :: 'Ret(anything)' then
      res := op(1,m);
      for i in loops do
        res := ary(op([2,2],i), op(1, i), res);
      end do;
      applyintegrand(h, res);
    elif m :: 'Bind(anything, name, anything)' then
      res := eval(op(3,m), op(2,m) = mk_idx(op(2,m), loops));
      res := eval(Integrand(op(2,m), 'integrate'(res, x, loops)), x=h);
      integrate(op(1,m), res , loops);
    elif m :: 'specfunc(Msum)' then
      `+`(op(map(integrate, [op(m)], h, loops)))
    elif m :: 'Weight(anything, anything)' then
      foldl(product, op(1,m), op(loops)) * integrate(op(2,m), h, loops)
    elif m :: t_pw
      and not depends([seq(op(i,m), i=1..nops(m)-1, 2)], map(lhs, loops)) then
      n := nops(m);
      piecewise(seq(`if`(i::even or i=n, integrate(op(i,m), h, loops), op(i,m)),
                    i=1..n))
    elif m :: t_case and not depends(op(1,m), map(lhs, loops)) then
      subsop(2=map(proc(b :: Branch(anything, anything))
                     eval(subsop(2='integrate'(op(2,b), x, loops),b), x=h)
                   end proc,
                   op(2,m)),
             m);
    elif m :: 'LO(name, anything)' then
      eval(op(2,m), op(1,m) = h)
    elif m :: 'Plate'('ary'(anything, name, anything)) then
      integrate(op([1,3],m), h, [op([1,2],m)=1..op([1,1],m), op(loops)]);
    elif h :: procedure then
      x := gensym('xa');
      'integrate'(m, Integrand(x, h(x)), loops)
    else
      'procname(_passed)'
    end if
  end proc;

  mk_idx := proc(nm :: name, loops :: list(name = range))
    foldr((x, y) -> idx(y, op(1,x)), nm, op(loops));
  end proc;
# Step 2 of 3: computer algebra

  improve := proc(lo :: LO(name, anything), {_ctx :: t_kb := empty})
    LO(op(1,lo), reduce(op(2,lo), op(1,lo), _ctx))
  end proc;

  cimprove := proc(c :: Context(t_kb, LO(name, anything)))
    Context(op(1,c), improve(op(2,c), _ctx = op(1,c)))
  end proc;

  ReparamDetermined := proc(lo :: LO(name, anything))
    local h;
    h := op(1,lo);
    LO(h,
       evalindets(op(2,lo),
                  'And'('specfunc({Int,int})',
                        'anyfunc'(anything, 'name=anything')),
                  g -> `if`(determined(op(1,g),h), Reparam(g,h), g)))
  end proc;

  determined := proc(e, h :: name)
    local ints, i;
    ints := indets(e, 'specfunc({Int,int})');
    for i in ints do
      if hastype(IntegrationTools:-GetIntegrand(i),
           'applyintegrand'('identical'(h),
             'dependent'(IntegrationTools:-GetVariable(i)))) then
        return false
      end if
    end do;
    return true
  end proc;

  Reparam := proc(e :: Int(anything, name=anything), h :: name)
    'procname(_passed)' # TODO to be implemented
  end proc;

  Banish := proc(e :: Int(anything, name=anything), h :: name,
                 levels :: extended_numeric := infinity)
    local hh;
    hh := gensym('h');
    subs(int=Int,
      banish(LO(hh, int(applyintegrand(hh,op([2,1],e)), op(2,e))),
        op([2,1],e), h, op(1,e), levels));
  end proc;

  # Walk through integrals and simplify, recursing through grammar
  # h - name of the linear operator above us
  # kb - domain information
  reduce := proc(ee, h :: name, kb :: t_kb)
    # option remember, system;
    local e, elim, hh, subintegral, w, ww,
          n, i, x, c, myint, res, rest, kb1, update_kb;
    e := ee;

    if e :: Int(anything, name=anything) then
      e := elim_int(e, h, kb);
      if e :: Int(anything, name=range) then
        x, kb1 := genLebesgue(op([2,1],e), op([2,2,1],e),
                                           op([2,2,2],e), kb);
        reduce_Int(reduce(subs(op([2,1],e)=x, op(1,e)), h, kb1),
                 h, kb1, kb)
      elif e <> ee then
        reduce(e, h, kb)
      else
        e
      end if;
    elif e :: 'Ints'(list, anything, name, range) then
      # TODO: we should have an elim_ints pass first
      reduce_Ints(op(e), h, kb);
    elif e :: `+` then
      map(reduce, e, h, kb)
    elif e :: `*` then
      (subintegral, w) := selectremove(depends, e, h);
      if subintegral :: `*` then error "Nonlinear integral %1", e end if;
      subintegral := convert(reduce(subintegral, h, kb), 'list', `*`);
      (subintegral, ww) := selectremove(depends, subintegral, h);
      reduce_pw(simplify_assuming(`*`(w, op(ww)), kb))
        * `*`(op(subintegral));
    elif e :: t_pw then
      n := nops(e);
      kb1 := kb;
      update_kb := proc(c)
        local kb0;
        kb0 := assert(    c , kb1);
        kb1 := assert(Not(c), kb1); # Mutation!
        kb0
      end proc;
      e := piecewise(seq(`if`(i::even, reduce(op(i,e), h, update_kb(op(i-1,e))),
                          `if`(i=n,    reduce(op(i,e), h, kb1),
                            simplify_assuming(op(i,e), kb1))),
                         i=1..n));
      # big hammer: simplify knows about bound variables, amongst many
      # other things
      Testzero := x -> evalb(simplify(x) = 0);
      reduce_pw(e)
    elif e :: t_case then
      subsop(2=map(proc(b :: Branch(anything, anything))
                     eval(subsop(2='reduce'(op(2,b),x,c),b),
                          {x=h, c=kb})
                   end proc,
                   op(2,e)),
             e);
    elif e :: 'integrate(anything, Integrand(name, anything), list)' then
      x := gensym(op([2,1],e));
      # If we had HType information for op(1,e),
      # then we could use it to tell kb about x.
      subsop(2=Integrand(x, reduce(subs(op([2,1],e)=x, op([2,2],e)), h, kb)), e)
    elif e :: 'ProductIntegral'(anything, name, anything) then
      error "we should never encounter this now"
    elif e :: 'applyintegrand'(anything, 'ary'(anything, name, anything)) then
      # array eta
      if op([2,3],e) :: 'idx'(anything, name) and (op([2,2],e) = op([2,3,2],e)) then
        applyintegrand(op(1,e), op([2,3,1], e))
      else
        e
      end if;
    else
      simplify_assuming(e, kb)
    end if;
  end proc;

  elim_int := proc(ee, h :: name, kb :: t_kb)
    local e, hh, elim;

    e := ee;
    while e :: Int(anything, name=anything) and not hastype(op(1,e),
       'applyintegrand'('identical'(h), 'dependent'(op([2,1],e)))) do
      # try to eliminate unused var
      hh := gensym('h');
      elim := eval(banish(LO(hh, myint(applyintegrand(hh,op([2,1],e)),op(2,e))),
                          op([2,1],e), h, op(1,e), infinity),
                   myint = proc(e,r)
                     subs(int=Int, simplify_assuming(int(e,r), kb))
                   end proc);
      if has(elim, {MeijerG, undefined})
         or numboccur(elim,Int) >= numboccur(e,Int) then
        # Maple was too good at integration
        break;
      end if;
      e := elim;
    end do;
    e;
  end proc;

  reduce_pw := proc(ee) # ee may or may not be piecewise
    local e;
    e := nub_piecewise(ee);
    if e :: t_pw then
      if nops(e) = 2 then
        return Indicator(op(1,e)) * op(2,e)
      elif nops(e) = 3 and Testzero(op(2,e)) then
        return Indicator(Not(op(1,e))) * op(3,e)
      elif nops(e) = 4 and Testzero(op(2,e)) then
        return Indicator(And(Not(op(1,e)),op(3,e))) * op(4,e)
      end if
    end if;
    return e
  end proc;

  reduce_Int := proc(ee, h :: name, kb1 :: t_kb, kb0 :: t_kb)
    local e, dom_spec, w, kb2, rest, var, new_rng, bound, indep, i;

    # if there are domain restrictions, try to apply them
    (dom_spec, e) := get_indicators(ee);
    rest := kb_subtract(foldr(assert, kb1, op(dom_spec)), kb0);
    new_rng, rest := selectremove(type, rest, [identical(genLebesgue),
                                               name, anything, anything]);
    new_rng := op(new_rng); # There should be exactly one genLebesgue
    var     := op(2,new_rng);
    new_rng := op(3,new_rng)..op(4,new_rng);
    dom_spec, rest := selectremove(depends,
      map(proc(a::[identical(assert),anything]) op(2,a) end proc, rest), var);
    if type(e, `*`) then
      (e, w) := selectremove(depends, e, var); # pull out weight
      w := simplify_assuming(w, kb1);
    else
      w := 1;
    end if;
    e := Int(`if`(dom_spec=[],e,piecewise(And(op(dom_spec)),e,0)), var=new_rng);
    e := w*elim_int(e, h, kb0);
    e := mul(Indicator(i), i in rest)*e;
    e
  end proc;

  reduce_prod := proc(ww, var :: name)
    local w, w1, w2, i;
    if type(ww, `*`) then
      w := map(x -> [reduce_prod(x, var)], convert(ww, 'list'));
      (w1, w2) := mul(i[1], i=w), mul(i[2], i=w);
    elif type(ww, 'Product'(anything, name = range)) then
      (w1, w2) := reduce_prod(op(1,ww), var);
      w1 := Product(w1, op(2,ww));
      w2 := product(w2, op(2,ww));
    elif depends(ww, var) then
      (w1, w2) := (ww, 1)
    else
      (w1, w2) := (1, ww)
    end if;
    (w1, w2)
  end proc;

  reduce_wl := proc(wl :: list, var :: name, kb :: t_kb)
    local w, weights;
    weights := map(simplify_assuming, wl, kb);
    w := 1;
    weights := map(proc(ww)
        local w1, w2;
        (w1, w2) := reduce_prod(ww, var);
        w := w * w2;
        w1
      end proc, weights);
    simplify_assuming(w,kb), weights;
  end proc;

  reduce_Ints := proc(ww, ee, var :: name, rng, h :: name, kb :: t_kb)
    local w, wl, e, we, w0;
    # TODO we should do something with domain restrictions (see above) too
    # but right now, that is not needed by the tests, so just deal with
    # weights.
    e := reduce(ee, h, kb);
    (e, w0) := reduce_prod(e, var);
    if e :: 'Ints'(list, anything, name, range) and op(4,e) = rng then
      # nested Ints on same range, merge
      error "opportunity - nested Ints";
    end if;
    (w, wl) := reduce_wl(ww, var, kb);
    simplify_assuming(w*w0, kb) * Ints(wl, e, var, rng);
    (w, wl) := reduce_wl(ww, var, constraints);
    simplify_assuming(w*w0, constraints) * Ints(wl, e, var, rng);
  end proc;

  get_indicators := proc(e)
    local sub, inds, rest;
    if e::`*` then
      sub := map((s -> [get_indicators(s)]), [op(e)]);
      `union`(op(map2(op,1,sub))), `*`(op(map2(op,2,sub)))
    elif e::`^` then
      inds, rest := get_indicators(op(1,e));
      inds, subsop(1=rest, e)
    elif e::'Indicator(anything)' then
      {op(1,e)}, 1
    else
      {}, e
    end if
  end proc;

  banish := proc(m, x :: name, h :: name, g, levels :: extended_numeric)
    # LO(h, banish(m, x, h, g)) should be equivalent to Bind(m, x, LO(h, g))
    # but performs integration over x innermost rather than outermost.
    local guard, subintegral, w, y, yRename, lo, hi, mm, xx, hh, gg, ll;
    guard := proc(m, c) bind(m, x, piecewise(c, Ret(x), Msum())) end proc;
    if g = 0 then
      0
    elif levels <= 0 then
      integrate(m, Integrand(x, g), []) # is [] right ?
    elif not depends(g, x) then
      integrate(m, x->1, []) * g
    elif g :: `+` then
      map[4](banish, m, x, h, g, levels)
    elif g :: `*` then
      (subintegral, w) := selectremove(depends, g, h);
      if subintegral :: `*` then error "Nonlinear integral %1", g end if;
      banish(bind(m, x, weight(w, Ret(x))), x, h, subintegral, levels)
    elif g :: 'And'('specfunc({Int,int})',
                    'anyfunc'('anything','name'='range'('freeof'(h)))) then
      subintegral := op(1, g);
      y           := op([2,1], g);
      lo, hi      := op(op([2,2], g));
      if x = y or depends(m, y) then
        yRename     := gensym(y);
        subintegral := subs(y=yRename, subintegral);
        y           := yRename;
      end if;
      mm := m;
      if depends(lo, x) then mm := guard(mm, lo<y); lo := -infinity end if;
      if depends(hi, x) then mm := guard(mm, y<hi); hi :=  infinity end if;
      op(0,g)(banish(mm, x, h, subintegral, levels-1), y=lo..hi)
    elif g :: t_pw then
      foldr_piecewise(
        proc(cond, th, el) proc(m)
          if depends(cond, x) then
            banish(guard(m, cond), x, h, th, levels-1) + el(guard(m, Not(cond)))
          else
            piecewise_if(cond, banish(m, x, h, th, levels-1), el(m))
          end if
        end proc end proc,
        proc(m) 0 end proc,
        g)(m)
    elif g :: t_case then
      subsop(2=map(proc(b :: Branch(anything, anything))
                     eval(subsop(2='banish'(op(2,b),xx,hh,gg,ll),b),
                          {xx=x, hh=h, gg=g, ll=l})
                   end proc,
                   op(2,integral)),
             integral);
    elif g :: 'integrate(freeof(x), Integrand(name, anything), list)' then
      y := gensym(op([2,1],g));
      subsop(2=Integrand(y, banish(m, x, h,
        subs(op([2,1],g)=y, op([2,2],g)), levels-1)), g)
    else
      integrate(m, Integrand(x, g), [])
    end if
  end proc;

  # this code should not currently be used, it is just a snapshot in time
  Reparam := proc(e::Int(anything,name=range), h::name)
    local body, var, inds, xx, inv, new_e;

    # TODO improve the checks.
    if not has(body, {Int,int}) and hastype(e,'specfunc(applyintegrand)') then
      inds := indets(body, 'applyintegrand'('identical'(h), 'dependent'(var)));
      if nops(inds)=1 and op(2,inds[1]) :: algebraic and
         not hastype(body, t_pw) then
        xx := gensym('xx');
        inv := solve({op(2,inds[1])=xx}, {var});
        try
          new_e := IntegrationTools[Change](e, inv, xx);
          if not has(new_e,{'limit'}) then e := new_e end if;
        catch:
          # this will simply not change e
        end try;
      end if;
    end if;

    e;
  end proc;

  piecewise_if := proc(cond, th, el)
    # piecewise_if should be equivalent to `if`, but it produces
    # 'piecewise' and optimizes for when the 3rd argument is 'piecewise'
    if cond = true then
      th
    elif cond = false or Testzero(th - el) then
      el
    elif el :: t_pw then
      if nops(el) >= 2 and Testzero(th - op(2,el)) then
        applyop(Or, 1, el, cond)
      else
        piecewise(cond, th, op(el))
      end if
    elif Testzero(el) then
      piecewise(cond, th)
    else
      piecewise(cond, th, el)
    end if
  end proc;

  nub_piecewise := proc(pw) # pw may or may not be piecewise
    foldr_piecewise(piecewise_if, 0, pw)
  end proc;

  map_piecewise := proc(f,p)
    local i;
    if p :: t_pw then
      piecewise(seq(`if`(i::even or i=nops(p),f(op(i,p),_rest),op(i,p)),i=1..nops(p)))
    else
      f(p,_rest)
    end if
  end proc;

# Step 3 of 3: from Maple LO (linear operator) back to Hakaru

  fromLO := proc(lo :: LO(name, anything), {_ctx :: t_kb := empty})
    local h;
    h := gensym(op(1,lo));
    unintegrate(h, eval(op(2,lo), op(1,lo) = h), _ctx)
  end proc;

  fromCLO := proc(c :: Context(t_kb, LO(name, anything)))
    Context(op(1,c), fromLO(op(2,c), op(1,c)))
  end proc;

  unintegrate := proc(h :: name, integral, kb :: t_kb)
    local x, c, lo, hi, m, mm, w, w0, recognition, subintegral,
          n, i, k, kb1, update_kb,
          hh, pp, res, rest;
    if integral :: 'And'('specfunc({Int,int})',
                         'anyfunc'('anything','name'='range'('freeof'(h)))) then
      (lo, hi) := op(op([2,2],integral));
      x, kb1 := genLebesgue(op([2,1],integral), lo, hi, kb);
      subintegral := eval(op(1,integral), op([2,1],integral) = x);
      (w, m) := unweight(unintegrate(h, subintegral, kb1));
      recognition := recognize(w, x, lo, hi)
        assuming op(kb_to_assumptions(kb1));
      if recognition :: 'Recognized(anything, anything)' then
        # Recognition succeeded
        (w, w0) := factorize(op(2,recognition), x);
        weight(w0, bind(op(1,recognition), x, weight(w, m)))
      else
        # Recognition failed
        (w, w0) := factorize(w, x);
        m := weight(w, m);
        if hi <> infinity then
          m := piecewise(x < hi, m, Msum())
        end if;
        if lo <> -infinity then
          m := piecewise(lo < x, m, Msum())
        end if;
        weight(w0, bind(Lebesgue(), x, m))
      end if
    elif integral :: 'Ints'(list, anything, name, range) then
      if nops(op(1,integral)) > 1 then error "multi-dimensional array NIY" end if;
      w := op([1,1],integral);
      if w :: 'Product'(anything, name = range) then
        pp := op(1, w);
        i := op([2,1], w);
        k := op([2,2,2], w);
      else
        error "weights are expected to be a Product"
      end if;
      # method: unintegrate 'pp' as if it were a single integral
      # this code is stolen from the Int code above, and adapted.
      (lo, hi) := op(op(4,integral));
      x, kb1 := genLebesgue(op(3,integral), lo, hi, kb);
      hh := gensym('h');
      subintegral := eval(pp*applyintegrand(hh,x), idx(op(3,integral), i) = x);
      # note: we throw away this m term, as we know what it is
      (w, m) := unweight(unintegrate(hh, subintegral, kb1));
      # put the dependence back in
      rest := unintegrate(h, op(2,integral), kb);
      recognition := recognize(w, x, lo, hi)
        assuming op(kb_to_assumptions(kb1));
      if recognition :: 'Recognized(anything, anything)' then
        # Recognition succeeded
        (w, w0) := factorize(op(2,recognition), x);
        res := weight(w, op(1, recognition));
        res := eval(res, x = idx(op(3,integral),i));
      else
        # Recognition failed
        (w, w0) := factorize(w, x);
        if hi <> infinity then
          m := piecewise(x < hi, m, Msum())
        end if;
        if lo <> -infinity then
          m := piecewise(lo < x, m, Msum())
        end if;
        res := weight(w, Lebesgue()); # bind(Lebesgue(), x, m);
        res := eval(res, x = idx(op(3,integral),i));
      end if;
      weight(product(w0,i=1..k), bind(Plate(ary(k, i, res)), op(3,integral), rest));
    # elif integral :: 'ProductIntegral'(anything, name, anything) then
    #   m := unintegrate(h, op(1, integral), kb);
    #   (w,m) := unweight(m);
    #   mm := unintegrate(h, op(3, integral), kb);
    #   weight(w, bind(Plate(m), op(2,integral), mm));
    elif integral :: 'applyintegrand'('identical'(h), 'freeof'(h)) then
      Ret(op(2,integral))
    elif integral = 0 then
      Msum()
    elif integral :: `+` then
      Msum(op(map2(unintegrate, h, convert(integral, 'list'), kb)))
    elif integral :: `*` then
      (subintegral, w) := selectremove(depends, integral, h);

      if subintegral :: `*` then error "Nonlinear integral %1", integral end if;
      m := weight(w, unintegrate(h, subintegral, kb));
      if m :: Weight(anything, anything) then
        m := weight(simplify_assuming(op(1,m), kb), op(2,m));
      end if;
      m
    elif integral :: t_pw
         and `and`(seq(not (depends(op(i,integral), h)),
                       i=1..nops(integral)-1, 2)) then
      n := nops(integral);
      kb1 := kb;
      update_kb := proc(c)
        local kb0;
        kb0 := assert(    c , kb1);
        kb1 := assert(Not(c), kb1); # Mutation!
        kb0
      end proc;
      piecewise(seq(`if`(i::even, unintegrate(h, op(i,integral),
                                              update_kb(op(i-1,integral))),
                     `if`(i=n,    unintegrate(h, op(i,integral), kb1),
                      op(i,integral))),
                    i=1..n))
    elif integral :: t_case then
      subsop(2=map(proc(b :: Branch(anything, anything))
                     eval(subsop(2='unintegrate'(x,op(2,b),c),b),
                          {x=h, c=kb})
                   end proc,
                   op(2,integral)),
             integral);
    elif integral :: 'integrate'('freeof'(h), 'anything', identical([])) then
      x := 'x';
      if op(2,integral) :: 'Integrand(name, anything)' then
        x := op([2,1],integral);
      end if;
      x := gensym(x);
      # If we had HType information for op(1,e),
      # then we could use it to tell kb about x.
      (w, m) := unweight(unintegrate(h, applyintegrand(op(2,integral), x), kb));
      (w, w0) := factorize(w, x);
      weight(w0, bind(op(1,integral), x, weight(w, m)))
    else
      # Failure: return residual LO
      LO(h, integral)
    end if
  end proc;

  ###
  # prototype disintegrator - main entry point
  disint := proc(lo :: LO(name,anything), t::name)
    local h, integ, occurs, oper_call, ret, var, plan;
    h := gensym(op(1,lo));
    integ := eval(op(2,lo), op(1,lo) = h);
    map2(LO, h, disint2(integ, h, t, []));
  end proc;

  find_vars := proc(l)
    local NONE; # used as a placeholder
    map(proc(x) 
          if type(x, specfunc(%int)) then op([1,1],x)
          elif type(x, specfunc(%weight)) then NONE
          else error "don't know about command (%1)", x
          end if end proc,
         l);
  end proc;

  find_constraints := proc(l)
    map(proc(x) 
          if type(x, specfunc(%int)) then op(1,x)
          elif type(x, specfunc(%weight)) then NULL
          else error "don't know about command (%1)", x
          end if end proc,
         l);
  end proc;

  # only care about bound variables, not globals
  get_var_pos := proc(v, l)
    local p;
    if member(v, l, 'p') then VarPos(v,p) else NULL end if;
  end proc;

  invert := proc(to_invert, main_var, integral, h, path, t)
    local sol, dxdt, vars, in_sol, r_in_sol, p_mv, would_capture, flip;
    if type(to_invert, 'linear'(main_var)) then
      sol := solve([t = to_invert], {main_var})[1];

    else
      # TODO: split domain.
      # right now, assume that if solve returns a single answer, it's ok!
      sol := solve([t = to_invert], {main_var});
      if not (nops(sol) = 1) then
        error "non-linear inversion needed: %1 over %2", to_invert, main_var;
      else
        sol := sol[1];
      end if;
    end if;

    dxdt := diff(op(2, sol), t);
    flip := simplify_assuming(signum(dxdt), 
      [t = -infinity .. infinity, op(find_constraints(path))]);
    if not member(flip, {1,-1}) then
      error "derivative has symbolic sign (%1), what do we do?", flip
    end if;

    # we need to figure out what variables the solution depends on,
    # and what plan that entails
    vars := find_vars(path);
    in_sol := indets(sol, 'name') minus {t, main_var};

    member(main_var, vars, 'p_mv');
    r_in_sol := map(get_var_pos, in_sol, vars);
    would_capture := map2(op, 1, r_in_sol);

    # May have to pull the integral for main_var up a few levels
    interpret(
      [ %WouldCapture(main_var, p_mv, [seq(i, i in would_capture)])
      , %Change(main_var, t = to_invert, sol, flip)
      , %ToTop(t)
      , %Drop(t)],
      path, abs(dxdt) * 'applyintegrand'(h, eval(op([2,2],integral), sol)));
  end proc;

  # basic algorithm:
  # - follow the syntax
  # - collect the 'path' traversed (aka the "heap"); allows reconstruction
  # - when we hit a Ret, figure out the change of variables
  # - note that the callee is responsible for "finishing up"
  disint2 := proc(integral, h::name, t::name, path)
    local x, lo, hi, subintegral, w, n, m, w0, perform, script, vars,
      to_invert, sol, occurs, dxdt, kb1, update_kb;
    if integral :: 'And'('specfunc({Int,int})',
                         'anyfunc'('anything','name'='range'('freeof'(h)))) then
      x := op([2,1],integral);
      (lo, hi) := op(op([2,2],integral));
      perform := %int(op(2,integral));
      # TODO: enrich kb with x (measure class lebesgue)
      disint2(op(1,integral), h, t, [perform, op(path)]);
    elif integral :: 'applyintegrand'('identical'(h), 'freeof'(h)) then
      if not type(op(2,integral), specfunc(Pair)) then
        # this should probably be type-checked at the top!
        error "must return a Pair to enable disintegration";
      end if;
      to_invert := op([2,1], integral);
      vars := convert(find_vars(path),'set');
      occurs := remove(type, indets(to_invert, 'name'), 'constant') intersect vars;
      if nops(occurs) = 0 then
        error "cannot invert constant (%1)", to_invert
      else
        map[2](invert, to_invert, occurs, integral, h, path, t);
      end if;
    elif integral = 0 then
      error "cannot disintegrate 0 measure"
    elif integral :: `+` then
      sol := map(disint2, convert(integral, 'list'), h, t, path);
      error "on a `+`, got", sol;
    elif integral :: `*` then
      (subintegral, w) := selectremove(depends, integral, h);
      if subintegral :: `*` then error "Nonlinear integral %1", integral end if;
      disint2(subintegral, h, t, [%weight(w), op(path)]);
    elif integral :: t_pw
         and `and`(seq(not (depends(op(i,integral), h)),
                       i=1..nops(integral)-1, 2)) then
      n := nops(integral);
      kb1 := kb;
      update_kb := proc(c)
        local kb0;
        kb0 := assert(    c , kb1);
        kb1 := assert(Not(c), kb1); # Mutation!
        kb0
      end proc;
      error "need to map into piecewise";
      piecewise(seq(piecewise(i::even,
                              unintegrate(h, op(i,integral),
                                          update_kb(op(i-1,integral))),
                              i=n,
                              unintegrate(h, op(i,integral), kb1),
                              op(i,integral)),
                    i=1..n))
    elif integral :: 'integrate'('freeof'(h), 'anything', identical([])) then
      x := 'x';
      if op(2,integral) :: 'Integrand(name, anything)' then
        x := op([2,1],integral);
      end if;
      x := gensym(x);
      # we would be here mostly if the measure being passed in is
      # not known.  So error is fine, and should likely be caught
      # elsewhere
      error "what to do with (%1)", integral;
      # If we had HType information for op(1,e),
      # then we could use it to tell kb about x.
      (w, m) := unweight(unintegrate(h, applyintegrand(op(2,integral), x), kb));
      (w, w0) := factorize(w, x);
      weight(w0, bind(op(1,integral), x, weight(w, m)))
    else
      # Failure
      # LO(h, integral)
      error "why are we here?";
    end if
  end proc;

  # single step of reconstruction
  reconstruct := proc(step, part)
    if type(step, specfunc(%int)) then
      Int(part, op(1, step));
    elif type(step, specfunc(%weight)) then
      op(1, step) * part
    else
      error "how to reconstruct (%1)", step
    end if;
  end proc;

  get_int_pos := proc(var, path)
    local finder;
    finder := proc(loc) 
      if type(op(loc,path),specfunc(%int)) and op([loc,1,1], path) = var then
        loc
      else
        NULL # cheating...
      end if
    end proc;
    seq(finder(i),i=1..nops(path)); 
  end proc;

  change_var := proc(act, chg, path, part)
    local bds, new_upper, new_lower, new_path, flip, var, finder, pos,
       DUMMY;

    # first step, find where the relevant integral is
    var := op(1,act);
    pos := get_int_pos(var, path);
    new_path := eval(subsop(pos=DUMMY, path), op(3,act));

    bds := op([pos,1,2], path);
    new_upper := limit(op([2,2], act), op(1, act) = op(2,bds), left);
    new_lower := limit(op([2,2], act), op(1, act) = op(1,bds), right);
    flip := op(4,act);
    if flip=-1 then
      (new_lower, new_upper) := (new_upper, new_lower);
    end if;
    if new_upper = infinity and new_lower = -infinity then
      # we're done with this integral, put it back on path
      new_path := subsop(pos = %int(t = -infinity .. infinity), new_path);
      interpret(chg, new_path, part)
    else
      # right now, putting in new constraints "innermost", while
      # they really ought to be floated up as far as possible.
      # Probably leave that to improve?
      new_path := subsop(pos = %int(t = new_lower.. new_upper), new_path);
      interpret(chg, new_path,
	piecewise(And(new_lower < t, t < new_upper), part, 0));
    end if;
  end proc;

  # avoid_capture is essentially "inverse banish", where we pull integrals
  # up rather than pushing them down.  The list contains which variables
  # would be captured by the 'main' one.  %Top is a special variable that
  # just means that we should just push the one integral to the top, but
  # there's no need to rearrange anything else.
  avoid_capture := proc(task :: %WouldCapture(name, posint, list), chg, path, part)
    local x, p, here, there, vars, new_path, go_past, to_top, work, n, pos, 
      y, v, scope;

    go_past := convert(map2(op, 1, op(3,task)), 'set');
    to_top := member(%Top, go_past);
    if to_top and nops(go_past)>1 then
      error "cannot ask to promote to top and past some variables";
    end if;

    if nops(go_past)=0 then # nothing to do, next
      interpret(chg, path, part)
    else
      n := nops(path);
      x := op(1,task);
      p := op(2,task);

      if p = n and to_top then
        return interpret(chg, path, part)
      end if;

      # two-pass algorithm:
      # 1. push the integral on the main variable "up", past the others
      # 2. push all the weights "down" into scope

      # for efficiency, work with a table, not a list
      pos := p+1;
      work := evalb(pos <= n);
      new_path := table(path);
      here  := path[p];

      # first pass
      while work do
        y := new_path[pos];
        if type(y, specfunc(%weight)) then
          new_path[pos-1] := y;
          new_path[pos] := here;
          pos := pos + 1;
        elif type(y, specfunc(%int)) then
          v := op([1,1], y);
          go_past := go_past minus {v};
          # TODO: surely we're missing a test here for the bounds
          new_path[pos-1] := y;
          new_path[pos] := here;
          pos := pos + 1;
          work := evalb(go_past = {} and pos <= n);
        else
          error "How do I move past a %1 ?", eval(y);
        end if;
      end do;

      # second pass
      scope := NULL;
      for pos from n to 2 by -1 do
        y := new_path[pos];
        if type(y, specfunc(%int)) then
          scope := op([1,1], y), scope;
        elif type(y, specfunc(%weight)) then
          vars := indets(y, 'name');
          vars := `if`(member(x, vars), vars union go_past, vars);
          vars := vars intersect go_past;
          if vars <> {} then # if no problem vars, keep going
            there := new_path[pos-1];
            if type(there, specfunc(%int)) then
              # TODO: surely we're missing a test here for the bounds
              scope := op([1,1], there), scope;
              new_path[pos-1] := y;
              new_path[pos] := there;
            elif type(there, specfunc(%weight)) then
              new_path[pos-1] := %weight(op(1,y) * op(1, there));
              new_path[pos] := %weight(1); # don't mess up the length
            else
              error "how do I move a weight below a %1", there;
            end if;
          end if;
        else
          error "How do I move below a %1 ?", y;
        end if;
      end do;

      interpret(chg, [seq(new_path[i], i=1..nops(path))], part);
    end if;
  end proc;

  # interpret a plan
  # chg : plan of what needs to be done
  # path : context, allows one to reconstruct the incoming expression
  # part: partial answer
  interpret := proc(chg, path, part)
    local i, ans, pos, var;
    if path=[] then part
    elif chg=[] then # finished changes, just reconstruct
      ans := part;
      for i from 1 to nops(path) do
        ans := reconstruct(path[i], ans);
      end do;
      return ans;
    elif type(chg[1], specfunc(%Change)) then
      change_var(chg[1], chg[2..-1], path, part);
    elif type(chg[1], specfunc(%WouldCapture)) then
      avoid_capture(chg[1], chg[2..-1], path, part);
    elif type(chg[1], specfunc(%ToTop)) then
      var := op([1,1], chg);
      if type(path[-1], specfunc(%int)) and op([-1,1,1], path) = var then
        interpret(chg[2..-1], path, part)
      else

        pos := get_int_pos(var, path);
        interpret([%WouldCapture(var, pos, [%Top]), op(2..-1,chg)], path, part); 
      end if;
    elif type(chg[1], specfunc(%Drop)) then
      if type(path[-1], specfunc(%int)) and op([-1,1,1], path) = op([1,1], chg) then
        interpret(chg[2..-1], path[1..-2], part)
      else
        error "asked to drop t-integral (%1, %2), but it is not at top ",
          path, part
      end if;
    else
      error "unknown plan step: %1", chg[1]
    end if;
  end proc;
  ###
  # smart constructors for our language

  bind := proc(m, x, n)
    if n = 'Ret'(x) then
      m # monad law: right identity
    elif m :: 'Ret(anything)' then
      eval(n, x = op(1,m)) # monad law: left identity
    elif m :: 'Weight(anything, anything)' then
      op(1,m)*bind(op(2,m), x, n)
    else
      'Bind(_passed)'
    end if;
  end proc;

  weight := proc(p, m)
    if p = 1 then
      m
    elif p = 0 then
      Msum()
    elif m :: 'Weight(anything, anything)' then
      weight(p * op(1,m), op(2,m))
    else
      'Weight(_passed)'
    end if;
  end proc;

  case := proc(e, bs :: specfunc(Branch(anything, anything), Branches))
    local ret, b, substs, eSubst, pSubst, p, binds, uncertain;
    ret := Branches();
    for b in bs do
      substs := pattern_match(e, e, op(1,b));
      if substs <> NULL then
        eSubst, pSubst := substs;
        p := subs(pSubst, op(1,b));
        binds := {pattern_binds(p)};
        uncertain := remove((eq -> lhs(eq) in binds), eSubst);
        if nops(uncertain) = 0 then p := PWild end if;
        ret := Branches(op(ret),
                        Branch(p, eval(eval(op(2,b), pSubst), eSubst)));
        if nops(uncertain) = 0 then break end if;
      end if
    end do;
    if ret :: Branches(Branch(identical(PWild), anything)) then
      op([1,2], ret)
    elif ret :: Branches(Branch(identical(p_true), anything),
                         Branch({identical(p_false),
                                 identical(PWild),
                                 PVar(anything)}, anything)) then
      piecewise(make_piece(e), op([1,2], ret), op([2,2], ret))
    elif ret :: Branches(Branch(identical(p_false), anything),
                         Branch({identical(p_true),
                                 identical(PWild),
                                 PVar(anything)}, anything)) then
      piecewise(make_piece(e), op([2,2], ret), op([1,2], ret))
    else
      'case'(e, ret)
    end if
  end proc;

  Datum := proc(hint, payload)
    # Further cheating to equate Maple booleans and Hakaru booleans
    if hint = true and payload = Inl(Done) or
       hint = false and payload = Inr(Inl(Done)) then
      hint
    else
      'procname(_passed)'
    end if
  end proc;

  app := proc (func, argu)
    if func :: lam(name, anything) then
      eval(op(2,func), op(1,func)=argu)
    elif func :: t_pw then
      map_piecewise(procname, _passed)
    else
      'procname(_passed)'
    end if
  end proc;

  idx := proc (a, i)
    if a :: 'ary'(anything, name, anything) then
      eval(op(3,a), op(2,a)=i)
    elif a :: t_pw then
      map_piecewise(procname, _passed)
    else
      'procname(_passed)'
    end if
  end proc;

  unweight := proc(m)
    local total, ww, mm;
    if m :: 'Weight(anything, anything)' then
      op(m)
    elif m :: 'specfunc(Msum)' then
      total := `+`(op(map((mi -> unweight(mi)[1]), m)));
      (total, map((mi -> weight(1/total, mi)), m))
    else
      # TODO: Better weight estimate for piecewise & density-recognition cases?
      (1, m)
    end if;
  end proc;

  factorize := proc(weight, x)
    # return (weight, 1); # uncomment this to disable factorization
    if weight :: `*` then
      selectremove(depends, weight, x)
    elif depends(weight, x) then
      (weight, 1)
    else
      (1, weight)
    end if
  end proc;

  pattern_match := proc(e0, e, p)
    local x, substs, eSubst, pSubst;
    if p = PWild then return {}, {}
    elif p :: PVar(anything) then
      x := op(1,p);
      pSubst := {`if`(depends(e0,x), x=gensym(x), NULL)};
      return {subs(pSubst,x)=e}, pSubst;
    elif p = p_true then
      if e = true then return {}, {}
      elif e = false then return NULL
      end if
    elif p = p_false then
      if e = false then return {}, {}
      elif e = true then return NULL
      end if
    elif p :: PDatum(anything, anything) then
      if e :: Datum(anything, anything) then
        if op(1,e) = op(1,p) then return pattern_match(e0, op(2,e), op(2,p))
        else return NULL
        end if
      end if
    elif p :: PInl(anything) then
      if e :: Inl(anything) then return pattern_match(e0, op(1,e), op(1,p))
      elif e :: Inr(anything) then return NULL
      end if
    elif p :: PInr(anything) then
      if e :: Inr(anything) then return pattern_match(e0, op(1,e), op(1,p))
      elif e :: Inl(anything) then return NULL
      end if
    elif p :: PEt(anything, anything) then
      if e :: Et(anything, anything) then
        substs := pattern_match(e0, op(1,e), op(1,p));
        if substs = NULL then return NULL end if;
        eSubst, pSubst := substs;
        substs := pattern_match(e0, eval(op(2,e),eSubst), op(2,p));
        if substs = NULL then return NULL end if;
        return eSubst union substs[1], pSubst union substs[2];
      elif e = Done then return NULL
      end if
    elif p = PDone then
      if e = Done then return {}, {}
      elif e :: Et(anything, anything) then return NULL
      end if
    elif p :: PKonst(anything) then
      if e :: Konst(anything) then return pattern_match(e0, op(1,e), op(1,p))
      end if
    elif p :: PIdent(anything) then
      if e :: Ident(anything) then return pattern_match(e0, op(1,e), op(1,p))
      end if
    else
      error "pattern_match: %1 is not a pattern", p
    end if;
    pSubst := map((x -> `if`(depends(e0,x), x=gensym(x), NULL)),
                  {pattern_binds(p)});
    eSubst := {e=evalindets(
                   evalindets[nocache](
                     subs(pSubst,
                          p_true=true,
                          p_false=false,
                          PDatum=Datum, PInr=Inr, PInl=Inl, PEt=Et, PDone=Done,
                          PKonst=Konst, PIdent=Ident,
                          p),
                     identical(PWild),
                     p -> gensym(_)),
                   PVar(anything),
                   p -> op(1,p))};
    eSubst, pSubst
  end proc;

  make_piece := proc(rel)
    # Try to prevent PiecewiseTools:-Is from complaining
    # "Wrong kind of parameters in piecewise"
    if rel :: {specfunc(anything, {And,Or,Not}), `and`, `or`, `not`} then
      map(make_piece, rel)
    elif rel :: {'`::`', 'boolean', '`in`'} then
      rel
    else
      rel = true
    end if
  end proc;

  recognize := proc(weight0, x, lo, hi)
    local Constant, weight, de, Dx, f, w, res, rng;
    res := FAIL;
    # gfun[holexprtodiffeq] contains a test for {radfun,algfun} that seems like
    # it should test for {radfun(anything,x),algfun(anything,x)} instead.
    # Consequently, it issues the error "expression is not holonomic: %1" for
    # actually holonomic expressions such as exp(x*sum(g(i,j),j=1..n)).
    # Moreover, mysolve has trouble solve-ing constraints involving sum, etc.
    # To work around these weaknesses, we wrap sum(...), etc. in Constant[...].
    # Unlike sum(...), Constant[sum(...)] passes the type test {radfun,algfun},
    # which we need to handle exp(x*sum(...)) using gfun[holexprtodiffeq].
    # Like sum(...i...), Constant[sum(...i...)] depends on i, which we need so
    # that product(sum(...i...),i=1..m) doesn't simplify to ...^m.
    weight := evalindets[flat](weight0,
                And(# Not(radfun), Not(algfun),
                    'specfunc({%product, product, sum, idx})',
                    'freeof'(x)),
                proc(e) Constant[e] end);
    de := get_de(weight, x, Dx, f);
    if de :: 'Diffop(anything, anything)' then
      res := recognize_de(op(de), Dx, f, x, lo, hi)
    end if;
    if res = FAIL then
      rng := hi - lo;
      w := simplify(weight * (hi - lo));
      # weight could be piecewise and simplify will hide the problem
      if not (rng :: 'SymbolicInfinity'
              or w :: {'SymbolicInfinity', 'undefined'}) then
        res := Recognized(Uniform(lo, hi), w)
      end if
    end if;
    # Undo Constant[...] wrapping
    evalindets[flat](res, 'specindex'(anything, Constant), x -> op(1,x))
  end proc;

  get_de := proc(dens, var, Dx, f)
    :: Or(Diffop(anything, set(function=anything)), identical(FAIL));
    local de, init;
    try
      de := gfun[holexprtodiffeq](dens, f(var));
      de := gfun[diffeqtohomdiffeq](de, f(var));
      if not (de :: set) then
        de := {de}
      end if;
      init, de := selectremove(type, de, `=`);
      if nops(de) = 1 then
        if nops(init) = 0 then
          # TODO: Replace {0, 1/2, 1} by PyMC's distribution-specific "testval"
          init := map(proc (val)
                        try f(val) = eval(dens, var=val)
                        catch: NULL
                        end try
                      end proc,
                      {0, 1/2, 1})
        end if;
        return Diffop(DEtools[de2diffop](de[1], f(var), [Dx, var]), init)
      end if
    catch: # do nothing
    end try;
    FAIL
  end proc;

  recognize_de := proc(diffop, init, Dx, f, var, lo, hi)
    local dist, ii, constraints, w, a0, a1, a, b0, b1, c0, c1, c2, loc, nu;
    dist := FAIL;
    if lo = -infinity and hi = infinity
       and ispoly(diffop, 'linear', Dx, 'a0', 'a1') then
      a := normal(a0/a1);
      if ispoly(a, 'linear', var, 'b0', 'b1') then
        dist := Gaussian(-b0/b1, sqrt(1/b1))
      elif ispoly(numer(a), 'linear', var, 'b0', 'b1') and
           ispoly(denom(a), 'quadratic', var, 'c0', 'c1', 'c2') then
        loc := -c1/c2/2;
        if Testzero(b0 + loc * b1) then
          nu := b1/c2 - 1;
          if Testzero(nu - 1) then
            dist := Cauchy(loc, sqrt(c0/c2-loc^2))
          else
            dist := StudentT(nu, loc, sqrt((c0/c2-loc^2)/nu))
          end if
        end if
      end if;
    elif lo = 0 and hi = 1
         and ispoly(diffop, 'linear', Dx, 'a0', 'a1')
         and ispoly(normal(a0*var*(1-var)/a1), 'linear', var, 'b0', 'b1') then
      dist := BetaD(1-b0, 1+b0+b1)
    elif lo = 0 and hi = infinity
         and ispoly(diffop, 'linear', Dx, 'a0', 'a1')
         and ispoly(normal(a0*var/a1), 'linear', var, 'b0', 'b1') then
      dist := GammaD(1-b0, 1/b1)
    end if;
    if dist <> FAIL then
      try
        ii := map(convert, init, 'diff');
        constraints := eval(ii, f = (x -> w*density[op(0,dist)](op(dist))(x)));
        w := eval(w, mysolve(simplify(constraints), w));
        if not (has(w, 'w')) then
          return Recognized(dist, simplify(w))
        end if
      catch: # do nothing
      end try;
      WARNING("recognized %1 as %2 but could not solve %3", f, dist, init)
    end if;
    FAIL
  end proc;

  mysolve := proc(constraints)
    # This wrapper around "solve" works around the problem that Maple sometimes
    # thinks there is no solution to a set of constraints because it doesn't
    # recognize the solution to each constraint is the same.  For example--
    # This fails     : solve({c*2^(-1/2-alpha) = sqrt(2)/2, c*4^(-alpha) = 2^(-alpha)}, {c}) assuming alpha>0;
    # This also fails: solve(simplify({c*2^(-1/2-alpha) = sqrt(2)/2, c*4^(-alpha) = 2^(-alpha)}), {c}) assuming alpha>0;
    # But this works : map(solve, {c*2^(-1/2-alpha) = sqrt(2)/2, c*4^(-alpha) = 2^(-alpha)}, {c}) assuming alpha>0;
    # And the difference of the two solutions returned simplifies to zero.

    local result;
    if nops(constraints) = 0 then return NULL end if;
    result := solve(constraints, _rest);
    if result <> NULL or not (constraints :: {set,list}) then
      return result
    end if;
    result := mysolve(subsop(1=NULL,constraints), _rest);
    if result <> NULL
       and op(1,constraints) :: 'anything=anything'
       and simplify(eval(op([1,1],constraints) - op([1,2],constraints),
                         result)) <> 0 then
      return NULL
    end if;
    result
  end proc;

  density[Lebesgue] := proc() proc(x) 1 end proc end proc;
  density[Uniform] := proc(a,b) proc(x)
    1/(b-a)
  end proc end proc;
  density[Gaussian] := proc(mu, sigma) proc(x)
    1/sigma/sqrt(2)/sqrt(Pi)*exp(-(x-mu)^2/2/sigma^2)
  end proc end proc;
  density[Cauchy] := proc(loc, scale) proc(x)
    1/Pi/scale/(1+((x-loc)/scale)^2)
  end proc end proc;
  density[StudentT] := proc(nu, loc, scale) proc(x)
    GAMMA((nu+1)/2) / GAMMA(nu/2) / sqrt(Pi*nu) / scale
    * (1 + ((x-loc)/scale)^2/nu)^(-(nu+1)/2)
  end proc end proc;
  density[BetaD] := proc(a, b) proc(x)
    x^(a-1)*(1-x)^(b-1)/Beta(a,b)
  end proc end proc;
  # Hakaru uses the alternate definition of gamma, so the args are backwards
  density[GammaD] := proc(shape, scale) proc(x)
    x^(shape-1)/scale^shape*exp(-x/scale)/GAMMA(shape);
  end proc end proc;

  bounds[Lebesgue] := proc() -infinity .. infinity end proc;
  bounds[Uniform] := proc(a, b) a .. b end proc;
  bounds[Gaussian] := proc(mu, sigma) -infinity .. infinity end proc;
  bounds[Cauchy] := proc(loc, scale) -infinity .. infinity end proc;
  bounds[StudentT] := proc(mu, sigma) -infinity .. infinity end proc;
  bounds[BetaD] := proc(nu, loc, scale) 0 .. 1 end proc;
  bounds[GammaD] := proc(a, b) 0 .. infinity end proc;

  RoundTrip := proc(e, t::t_type, {kb :: t_kb := empty})
      lprint(eval(ToInert(Simplify(e,t,kb)),
        _Inert_ATTRIBUTE=NULL))
  end proc;

  RoundTripLO := proc(m, {ctx :: t_kb := empty})
      lprint(eval(ToInert(fromLO(improve(toLO(m), _ctx = ctx), _ctx = ctx)), 
        _Inert_ATTRIBUTE=NULL))
  end proc;

  RoundTripCLO := proc(m :: Context(t_kb, anything))
      sprintf("%a",(eval(ToInert(fromCLO(cimprove(toCLO(m)))), _Inert_ATTRIBUTE=NULL)))
  end proc;

# Testing

  TestHakaru := proc(m,n::algebraic:=m,{simp:=improve,verify:=simplify,ctx:=empty})
    CodeTools[Test](fromLO(simp(toLO(m), _ctx = ctx), _ctx = ctx), n,
      measure(verify), _rest)
  end proc;

  TestSimplify := proc(m,t,n::algebraic:=m,{verify:=simplify,ctx:=empty})
    CodeTools[Test](Simplify(m,t,ctx), n, measure(verify), _rest)
  end proc;

  verify_measure := proc(m, n, v:='boolean')
    local mv, x, i, j, k;
    mv := measure(v);
    if verify(m, n, 'Bind'(mv, true, true)) then
      x := gensym(cat(op(2,m), "_", op(2,n), "_"));
      thisproc(subs(op(2,m)=x, op(3,m)),
               subs(op(2,n)=x, op(3,n)), v)
    elif m :: 'specfunc(Msum)' and n :: 'specfunc(Msum)'
         and nops(m) = nops(n) then
      k := nops(m);
      verify(k, GraphTheory[BipartiteMatching](GraphTheory[Graph]({
                seq(seq(`if`(thisproc(op(i,m), op(j,n), v), {i,-j}, NULL),
                        j=1..k), i=1..k)}))[1]);
    elif m :: t_pw and n :: t_pw and nops(m) = nops(n) then
      k := nops(m);
      verify(m, n, 'piecewise'(seq(`if`(i::even or i=k, mv, v), i=1..k)))
    elif verify(m, n, 'case'(v, specfunc(Branch(true, true), Branches))) then
      # This code unfortunately only handles alpha-equivalence for 'case' along
      # the control path -- not if 'case' occurs in the argument to 'Ret', say.
      k := nops(op(2,m));
      for i from 1 to k do
        j := pattern_equiv(op([2,i,1],m), op([2,i,1],n));
        if j = false then return j end if;
        j := map(proc(eq)
                   local x;
                   x := gensym(cat(lhs(eq), "_", rhs(eq), "_"));
                   [lhs(eq)=x, rhs(eq)=x]
                 end proc, j);
        j := thisproc(subs(map2(op,1,j), op([2,i,2],m)),
                      subs(map2(op,2,j), op([2,i,2],n)), v);
        if j = false then return j end if;
      end do;
      true
    elif m :: 'LO(name, anything)' and n :: 'LO(name, anything)' then
      x := gensym(cat(op(1,m), "_", op(1,n), "_"));
      verify(subs(op(1,m)=x, op(2,m)),
             subs(op(1,n)=x, op(2,n)), v)
    elif m :: 'lam(name, anything)' and n :: 'lam(name, anything)' then
      # m and n are not even measures, but we verify them anyway...
      x := gensym(cat(op(1,m), "_", op(1,n), "_"));
      thisproc(subs(op(1,m)=x, op(2,m)),
               subs(op(1,n)=x, op(2,n)), v)
    else
      verify(m, n, {v,
        Lebesgue(),
        Uniform(v, v),
        Gaussian(v, v),
        Cauchy(v, v),
        StudentT(v, v, v),
        BetaD(v, v),
        GammaD(v, v),
        Ret(mv),
        Weight(v, mv)
      })
    end if
  end proc;

  pattern_equiv := proc(p, q) :: {identical(false),set(`=`)};
    local r, s;
    if ormap((t->andmap(`=`, [p,q], t)), [PWild, PDone]) then
      {}
    elif andmap(type, [p,q], PVar(anything)) then
      {op(1,p)=op(1,q)}
    elif andmap(type, [p,q], PDatum(anything,anything)) and op(1,p)=op(1,q) then
      pattern_equiv(op(2,p),op(2,q))
    elif ormap((t->andmap(type, [p,q], t(anything))),
               [PInl, PInr, PKonst, PIdent]) then
      pattern_equiv(op(1,p),op(1,q))
    elif andmap(type, [p,q], PEt(anything, anything)) then
      r := pattern_equiv(op(1,p),op(1,q));
      s := pattern_equiv(op(2,p),op(2,q));
      if map(lhs,r) intersect map(lhs,s) = {} and
         map(rhs,r) intersect map(rhs,s) = {} then
        r union s
      else
        false
      end if
    else
      false
    end if
  end proc;

  ModuleLoad := proc()
    KB; # Make sure the KB module is loaded, for the types t_type and t_kb
    VerifyTools[AddVerification](measure = verify_measure);
  end proc;

  ModuleUnload := proc()
    VerifyTools[RemoveVerification](measure);
  end proc;

  ModuleLoad();

end module; # NewSLO
