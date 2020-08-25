#=

birth-death MCMC

Ignacio Quintero Mächler

t(-_-t)

Created 25 08 2020
=#




"""
    insane_cbd(tree    ::iTree, 
               out_file::String;
               λprior  ::Float64 = 0.1,
               μprior  ::Float64 = 0.1,
               niter   ::Int64   = 1_000,
               nthin   ::Int64   = 10,
               nburn   ::Int64   = 200,
               tune_int::Int64   = 100,
               λtni    ::Float64 = 1.0,
               μtni    ::Float64 = 1.0,
               obj_ar  ::Float64 = 0.4)

Run insane for constant pure-birth.
"""
function insane_cbd(tree    ::iTree, 
                    out_file::String;
                    λprior  ::Float64 = 0.1,
                    μprior  ::Float64 = 0.1,
                    niter   ::Int64   = 1_000,
                    nthin   ::Int64   = 10,
                    nburn   ::Int64   = 200,
                    tune_int::Int64   = 100,
                    λtni    ::Float64 = 1.0,
                    μtni    ::Float64 = 1.0,
                    obj_ar  ::Float64 = 0.4)

  # tree characters
  tl = treelength(tree)
  th = treeheight(tree)
  nt = sntn(tree)

  fixtree!(tree)

  scalef = makescalef(obj_ar)

  # make fix tree directory
  idv = iDir[]
  bit = BitArray{1}()
  makeiDir!(tree, idv, bit)

  # create wbr vector
  wbr = falses(lastindex(idv))

  # create da branches vector
  dabr = Int64[]

  # adaptive phase
  llc, prc, tree, λc, μc, λtn, μtn, idv, dabr = 
      mcmc_burn_cbd(tree, tl, nt, th, tune_int, λprior, μprior, 
        nburn, λtni, μtni, scalef, idv, wbr, dabr)

  # mcmc
  R = mcmc_cbd(tree, llc, prc, λc, μc, λprior, μprior,
        niter, nthin, λtn, μtn, th, idv, wbr, dabr)

  pardic = Dict(("lambda" => 1),("mu" => 2))

  write_ssr(R, pardic, out_file)

  return R
end




"""
    mcmc_burn_cbd(tree    ::iTree,
                  tl      ::Float64,
                  nt      ::Int64,
                  th      ::Float64,
                  tune_int::Int64,
                  λprior  ::Float64,
                  μprior  ::Float64,
                  nburn   ::Int64,
                  λtni    ::Float64, 
                  μtni    ::Float64, 
                  scalef  ::Function,
                  λprior  ::Float64,
                  μprior  ::Float64,
                  idv     ::Array{iDir,1},
                  wbr     ::BitArray{1},
                  dabr    ::Array{Int64,1})

MCMC da chain for constant birth-death.
"""
function mcmc_burn_cbd(tree    ::iTree,
                       tl      ::Float64,
                       nt      ::Int64,
                       th      ::Float64,
                       tune_int::Int64,
                       λprior  ::Float64,
                       μprior  ::Float64,
                       nburn   ::Int64,
                       λtni    ::Float64, 
                       μtni    ::Float64, 
                       scalef  ::Function,
                       idv     ::Array{iDir,1},
                       wbr     ::BitArray{1},
                       dabr    ::Array{Int64,1})

  # initialize acceptance log
  ltn = 0
  lup = 0.0
  lac = Float64[0.0,0.0]
  λtn = λtni
  μtn = μtni

  # starting parameters
  δ   = Float64(nt-1)/tl
  μc  = δ*rand()
  λc  = δ + μc
  llc = llik_cbd(tree, λc, μc)
  prc = logdexp(λc, λprior)

  for it in Base.OneTo(nburn)

    # λ proposal
    llc, prc, λc = λp(llc, prc, λc, lac, λtn, μc)

    # μ proposal
    llc, prc, μc = μp(llc, prc, μc, lac, μtn, λc)

    # graft proposal
    tree, llc = graftp(tree, th, λc, μc, idv, wbr, dabr)

    # prune proposal
    tree, llc = prunep(tree, λc, μc, idv, dabr)

    # log tuning parameters
    ltn += 1
    lup += 1.0
    if ltn == tune_int
      λtn = scalef(λtn,lac[1]/lup)
      μtn = scalef(μtn,lac[2]/lup)
      ltn = 0
    end

  end

  return llc, prc, tree, λc, μc, λtn, μtn, idv, dabr
end





"""
    mcmc_cbd(tree  ::iTree,
             llc   ::Float64,
             prc   ::Float64,
             λc    ::Float64,
             μc    ::Float64,
             λprior::Float64,
             μprior::Float64,
             niter ::Int64,
             nthin ::Int64,
             λtn   ::Float64,
             μtn   ::Float64, 
             th    ::Float64,
             idv   ::Array{iDir,1},
             wbr   ::BitArray{1},
             dabr  ::Array{Int64,1})

MCMC da chain for constant birth-death.
"""
function mcmc_cbd(tree  ::iTree,
                  llc   ::Float64,
                  prc   ::Float64,
                  λc    ::Float64,
                  μc    ::Float64,
                  λprior::Float64,
                  μprior::Float64,
                  niter ::Int64,
                  nthin ::Int64,
                  λtn   ::Float64,
                  μtn   ::Float64, 
                  th    ::Float64,
                  idv   ::Array{iDir,1},
                  wbr   ::BitArray{1},
                  dabr  ::Array{Int64,1})

  # logging
  nlogs = fld(niter,nthin)
  lthin, lit = 0, 0

  R = Array{Float64,2}(undef, nlogs, 5)

  for it in Base.OneTo(niter)

    # λ proposal
    llc, prc, λc = λp(llc, prc, λc, λtn, μc)

    # μ proposal
    llc, prc, μc = μp(llc, prc, μc, μtn, λc)

    # graft proposal
    tree, llc = graftp(tree, th, λc, μc, idv, wbr, dabr)

    # prune proposal
    tree, llc = prunep(tree, λc, μc, idv, dabr)

    # log parameters
    lthin += 1
    if lthin == nthin
      lit += 1
      @inbounds begin
        R[lit,1] = Float64(lit)
        R[lit,2] = llc
        R[lit,3] = prc
        R[lit,4] = λc
        R[lit,5] = μc
      end
      lthin = 0
    end

  end

  return R
end




"""
    λp(llc::Float64,
       prc::Float64,
       λc::Float64,
       lac::Array{Float64,1},
       λtn::Float64,
       μc ::Float64)

`λ` proposal function for constant birth-death in adaptive phase.
"""
function λp(llc::Float64,
            prc::Float64,
            λc ::Float64,
            lac::Array{Float64,1},
            λtn::Float64,
            μc ::Float64)

    λp = mulupt(λc, λtn)::Float64

    llp = llik_cbd(tree, λp, μc)
    prr = llrdexp_x(λp, λc, λprior)

    if -randexp() < (llp - llc + prr + log(λp/λc))
      llc     = llp::Float64
      prc    += prr::Float64
      λc      = λp::Float64
      lac[1] += 1.0
    end

    return llc, prc, λc
end




"""
    λp(llc::Float64,
       prc::Float64,
       λc::Float64,
       λtn::Float64,
       μc ::Float64)

`λ` proposal function for constant birth-death.
"""
function λp(llc::Float64,
            prc::Float64,
            λc::Float64,
            λtn::Float64,
            μc ::Float64)

    λp = mulupt(λc, λtn)::Float64

    llp = llik_cbd(tree, λp, μc)
    prr = llrdexp_x(λp, λc, λprior)

    if -randexp() < (llp - llc + prr + log(λp/λc))
      llc     = llp::Float64
      prc    += prr::Float64
      λc      = λp::Float64
    end

    return llc, prc, λc 
end




"""
    μp(llc::Float64,
       prc::Float64,
       μc::Float64,
       lac::Array{Float64,1},
       μtn::Float64,
       λc ::Float64)

`μ` proposal function for constant birth-death in adaptive phase.
"""
function μp(llc::Float64,
            prc::Float64,
            μc::Float64,
            lac::Array{Float64,1},
            μtn::Float64,
            λc ::Float64)

    μp = mulupt(μc, rand() < 0.3 ? μtn : 4.0*μtn)::Float64

    # one could make a ratio likelihood function
    llp = llik_cbd(tree, λc, μp)
    prr = llrdexp_x(μp, μc, μprior)

    if -randexp() < (llp - llc + prr + log(μp/μc))
      llc  = llp::Float64
      prc += prr::Float64
      μc   = μp::Float64
      lac[2] += 1.0
    end

    return llc, prc, μc 
end




"""
    μp(llc::Float64,
       prc::Float64,
       μc::Float64,
       μtn::Float64,
       λc ::Float64)

`μ` proposal function for constant birth-death.
"""
function μp(llc::Float64,
            prc::Float64,
            μc::Float64,
            μtn::Float64,
            λc ::Float64)

    μp = mulupt(μc, rand() < 0.3 ? μtn : 4.0*μtn)::Float64

    # one could make a ratio likelihood function
    llp = llik_cbd(tree, λc, μp)
    prr = llrdexp_x(μp, μc, μprior)

    if -randexp() < (llp - llc + prr + log(μp/μc))
      llc  = llp::Float64
      prc += prr::Float64
      μc   = μp::Float64
    end

    return llc, prc, μc 
end




"""
    graftp(tree::iTree,
           th  ::Float64,
           λc  ::Float64,
           μc  ::Float64,
           idv ::Array{iDir,1}, 
           wbr ::BitArray{1},
           dabr::Array{Int64,1})

Graft proposal function for constant birth-death.
"""
function graftp(tree::iTree,
                th  ::Float64,
                λc  ::Float64,
                μc  ::Float64,
                idv ::Array{iDir,1}, 
                wbr ::BitArray{1},
                dabr::Array{Int64,1})

  λn = lnr()
  μn = lnr()

  #simulate extinct lineage
  t0, t0h = sim_cbd_b(λn, μn, th)

      # if useful simulation
  if t0h < th

    # check this!!!!!!!
    llr = llik_cbd(t0, λc, μc) + log(λc) - 
          llik_cbd(t0, λn, μn) - log(λn)

    if -randexp() < llr
      llc += llr
      # randomly select branch to graft
      h, br, bri  = randbranch(th, t0h, idv, wbr)
      # graft branch
      dri = dr(br)
      tree = graftree!(tree, t0, dri, h, lastindex(dri), th, 0)
      # add graft to branch
      addda!(br)
      # log branch as being data augmented
      push!(dabr, bri)
    end
  end

  return tree, llc
end




"""
    prunep(tree::iTree,
           λc  ::Float64,
           μc  ::Float64,
           idv ::Array{iDir,1}, 
           dabr::Array{Int64,1})

Prune proposal function for constant birth-death.
"""
function prunep(tree::iTree,
                λc  ::Float64,
                μc  ::Float64,
                idv ::Array{iDir,1}, 
                dabr::Array{Int64,1})

  if lastindex(dabr) > 0
    dabri = rand(Base.OneTo(lastindex(dabr)))
    br    = idv[dabr[dabri]]
    dri   = dr(br)
    ldr   = lastindex(dri)
    wpr   = rand(Base.OneTo(da(br)))

    llr = - stree_ll_cbd(tree, 0.0, λc, μc, dri, ldr, wpr, 0, 1) - log(λc)

    if -randexp() < llr
      llc += llr
      tree = prunetree!(tree, dri, ldr, wpr, 0, 1)
      # remove graft from branch
      # add graft to branch
      rmda!(br)
      # log branch as being data augmented
      deleteat!(dabr, dabri)
    end
  end

  return tree, llc
end




"""
    lnr()

**LogNormal** random samples with median of `1`. 
"""
lnr() = @fastmath exp(randn())





