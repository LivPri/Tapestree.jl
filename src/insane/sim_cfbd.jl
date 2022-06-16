#=

constant fossilized birth-death simulation

Jérémy Andréoletti
Adapted from constant birth-death simulation by Ignacio Quintero Mächler

v(°-°v)

Created 07 10 2021
=#




"""
    sim_cfbd(t::Float64, λ::Float64, μ::Float64, ψ::Float64)

Simulate a constant fossilized birth-death `iTree` of height `t` with speciation
rate `λ`, extinction rate `μ` and fossilization rate `ψ`.
"""
function sim_cfbd(t::Float64, λ::Float64, μ::Float64, ψ::Float64)

  tw = cfbd_wait(λ, μ, ψ)

  if tw > t
    return sTfbd(t, false, false, false)
  end

  if λevent(λ, μ, ψ)
    # speciation
    return sTfbd(sim_cfbd(t - tw, λ, μ, ψ), 
                 sim_cfbd(t - tw, λ, μ, ψ), 
                 tw, false, false, false)
  elseif μevent(μ, ψ)
    # extinction
    return sTfbd(tw, true, false, false)
  else
    # fossil sampling
    return sTfbd(sim_cfbd(t - tw, λ, μ, ψ), tw, false, true, false)
  end
end




"""
    sim_cfbd(t::Float64,
             λ::Float64,
             μ::Float64,
             ψ::Float64,
             na::Int64,
             nf::Int64)

Simulate a constant fossilized birth-death `iTree` of height `t` with speciation
rate `λ`, extinction rate `μ` and fossilization rate `ψ`.
"""
function sim_cfbd(t::Float64,
                  λ::Float64,
                  μ::Float64,
                  ψ::Float64,
                  na::Int64,
                  nf::Int64)

  tw = cfbd_wait(λ, μ, ψ)

  if tw > t
    na += 1
    return sTfbd(t, false, false, false), na, nf
  end

  # speciation
  if λevent(λ, μ, ψ)
    d1, na, nf = sim_cfbd(t - tw, λ, μ, ψ, na, nf)
    d2, na, nf = sim_cfbd(t - tw, λ, μ, ψ, na, nf)

    return sTfbd(d1, d2, tw, false, false, false), na, nf
  # extinction
  elseif μevent(μ, ψ)
    return sTfbd(tw, true, false, false), na, nf
  # fossil sampling
  else
    nf += 1
    d1, na, nf = sim_cfbd(t - tw, λ, μ, ψ, na, nf)
    return sTfbd(d1, tw, false, true, false), na, nf
  end
end




"""
    _sim_cfbd_t(t   ::Float64,
                λ   ::Float64,
                μ   ::Float64,
                ψ   ::Float64,
                lr  ::Float64,
                lU  ::Float64,
                Iρi ::Float64,
                na  ::Int64,
                nn  ::Int64,
                nlim::Int64)

Simulate a constant fossilized birth-death `iTree` of height `t` with speciation
rate `λ`, extinction rate `μ` and fossilization rate `ψ` for terminal branches, 
conditioned on no fossilizations.
"""
function _sim_cfbd_t(t   ::Float64,
                     λ   ::Float64,
                     μ   ::Float64,
                     ψ   ::Float64,
                     lr  ::Float64,
                     lU  ::Float64,
                     Iρi ::Float64,
                     na  ::Int64,
                     nn  ::Int64,
                     nlim::Int64)

  if isfinite(lr) && nn < nlim

    tw = cfbd_wait(λ, μ, ψ)

    if tw > t
      na += 1
      nlr = lr
      if na > 1
        nlr += log(Iρi * Float64(na)/Float64(na-1))
      end
      if nlr < lr && lU >= nlr
        return sTfbd(), na, nn, NaN
      else
        return sTfbd(t, false, false, false), na, nn, nlr
      end
    end

    # speciation
    if λevent(λ, μ, ψ)
      nn += 1
      d1, na, nn, lr = 
        _sim_cfbd_t(t - tw, λ, μ, ψ, lr, lU, Iρi, na, nn, nlim)
      d2, na, nn, lr = 
        _sim_cfbd_t(t - tw, λ, μ, ψ, lr, lU, Iρi, na, nn, nlim)

      return sTfbd(d1, d2, tw, false, false, false), na, nn, lr
    # extinction
    elseif μevent(μ, ψ)

      return sTfbd(tw, true, false, false), na, nn, lr
    # fossil sampling
    else
      return sTfbd(), na, nn, NaN
    end
  end

  return sTfbd(), na, nn, NaN
end




"""
    _sim_cfbd_i(t   ::Float64,
                λ   ::Float64,
                μ   ::Float64,
                ψ   ::Float64,
                na  ::Int64,
                nf  ::Int64,
                nn  ::Int64,
                nlim::Int64)

Simulate a constant fossilized birth-death `iTree` of height `t` with 
speciation rate `λ`, extinction rate `μ` and fossilization rate `ψ` 
for internal branches, conditioned on no fossilizations.
"""
function _sim_cfbd_i(t   ::Float64,
                     λ   ::Float64,
                     μ   ::Float64,
                     ψ   ::Float64,
                     na  ::Int64,
                     nf  ::Int64,
                     nn  ::Int64,
                     nlim::Int64)

  if iszero(nf) && nn < nlim

    tw = cfbd_wait(λ, μ, ψ)

    if tw > t
      na += 1
      return sTfbd(t, false, false, false), na, nf, nn
    end

    # speciation
    if λevent(λ, μ, ψ)
      nn += 1
      d1, na, nf, nn = _sim_cfbd_i(t - tw, λ, μ, ψ, na, nf, nn, nlim)
      d2, na, nf, nn = _sim_cfbd_i(t - tw, λ, μ, ψ, na, nf, nn, nlim)

      return sTfbd(d1, d2, tw, false, false, false), na, nf, nn
    # extinction
    elseif μevent(μ, ψ)

      return sTfbd(tw, true, false, false), na, nf, nn
    # fossil sampling
    else
      return sTfbd(), na, 1, nn
    end
  end

  return sTfbd(), na, nf, nn
end




"""
    _sim_cfbd_it(t   ::Float64,
                 λ   ::Float64,
                 μ   ::Float64,
                 ψ   ::Float64,
                 lr  ::Float64,
                 lU  ::Float64,
                 Iρi ::Float64,
                 na  ::Int64,
                 nf  ::Int64,
                 nn  ::Int64,
                 nlim::Int64)

Simulate a constant fossilized birth-death `iTree` of height `t` with 
speciation rate `λ`, extinction rate `μ` and fossilization rate `ψ` 
for continuing internal branches, conditioned on no fossilizations.
"""
function _sim_cfbd_it(t   ::Float64,
                      λ   ::Float64,
                      μ   ::Float64,
                      ψ   ::Float64,
                      lr  ::Float64,
                      lU  ::Float64,
                      Iρi ::Float64,
                      na  ::Int64,
                      nn  ::Int64,
                      nlim::Int64)

  if lU < lr && nn < nlim

    tw = cfbd_wait(λ, μ, ψ)

    if tw > t
      na += 1
      lr += log(Iρi)
      return sTfbd(t, false, false, false), na, nn, lr
    end

    # speciation
    if λevent(λ, μ, ψ)
      nn += 1
      d1, na, nn, lr = 
        _sim_cfbd_it(t - tw, λ, μ, ψ, lr, lU, Iρi, na, nn, nlim)
      d2, na, nn, lr = 
        _sim_cfbd_it(t - tw, λ, μ, ψ, lr, lU, Iρi, na, nn, nlim)

      return sTfbd(d1, d2, tw, false, false, false), na, nn, lr
    # extinction
    elseif μevent(μ, ψ)

      return sTfbd(tw, true, false, false), na, nn, lr
    # fossil sampling
    else
      return sTfbd(), na, nn, NaN
    end
  end

  return sTfbd(), na, nn, NaN
end




"""
    cfbd_wait(n::Float64, λ::Float64, μ::Float64, ψ::Float64)

Sample a waiting time for constant fossilized birth-death when `n` species
are alive with speciation rate `λ` and extinction rate `μ`.
"""
cfbd_wait(n::Float64, λ::Float64, μ::Float64, ψ::Float64) = rexp(n*(λ + μ + ψ))




"""
    cfbd_wait(λ::Float64, μ::Float64, ψ::Float64)

Sample a per-lineage waiting time for constant fossilized birth-death
with speciation rate `λ` and extinction rate `μ`.
"""
cfbd_wait(λ::Float64, μ::Float64, ψ::Float64) = rexp(λ + μ + ψ)




"""
    λevent(λ::Float64, μ::Float64, ψ::Float64)

Return `true` if speciation event
"""
λevent(λ::Float64, μ::Float64, ψ::Float64) = (λ/(λ + μ + ψ)) > rand()




"""
    λevent(μ::Float64, ψ::Float64)

Return `true` if extinction event, conditioned on "not a speciation event"
"""
μevent(μ::Float64, ψ::Float64) = (μ/(μ + ψ)) > rand()



