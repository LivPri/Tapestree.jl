
"""

Utilities for Data Augmented Competition model

Ignacio Quintero Mächler

t(-_-t)

May 01 2017

"""




"""
  Markov chain probabilities 
  through fast analytical solution
"""
function Ptrfast(λ1::Float64, λ0::Float64, t::Float64)
  
  @fastmath begin

    sumλ ::Float64 = λ1 + λ0
    ex   ::Float64 = exp(-sumλ*t)
    sd1  ::Float64 = 1/sumλ
    λ1ex ::Float64 = λ1*ex
    λ0ex ::Float64 = λ0*ex

    ((sd1*(λ0 + λ1ex), sd1*(λ1 - λ1ex)), 
     (sd1*(λ0 - λ0ex), sd1*(λ1 + λ0ex)))
  end
end




"""
  Markov chain probabilities 
  through fast analytical solution
  conditional on starting value
"""
function Ptrfast_start(λ1::Float64, λ0::Float64, t::Float64, state::Int64)
  
  @fastmath begin

    sumλ ::Float64 = λ1 + λ0
    ex   ::Float64 = exp(-sumλ*t)
    sd1  ::Float64 = 1/sumλ
    λ1ex ::Float64 = λ1*ex
    λ0ex ::Float64 = λ0*ex

    if state == 0
      sd1*(λ0 + λ1ex), sd1*(λ1 - λ1ex) 
    else
      sd1*(λ0 - λ0ex), sd1*(λ1 + λ0ex)
    end
  end
end



"""
  Markov chain probabilities 
  through fast analytical solution
  conditional on starting value
"""
function Ptrfast_end(λ1::Float64, λ0::Float64, t::Float64, state::Int64)
  
  @fastmath begin

    sumλ ::Float64 = λ1 + λ0
    ex   ::Float64 = exp(-sumλ*t)
    sd1  ::Float64 = 1/sumλ
    λ1ex ::Float64 = λ1*ex
    λ0ex ::Float64 = λ0*ex

    if state == 0
      (sd1*(λ0 + λ1ex), sd1*(λ0 - λ0ex))
    else
      (sd1*(λ1 - λ1ex), sd1*(λ1 + λ0ex))
    end
  end
end




"""
  log-density of exponential 
"""
logdexp(x::Float64, λ::Float64) = @fastmath log(λ) - λ * x




"""
  log-density of normal
"""
logdnorm(x::Float64, μ::Float64, σ²::Float64) = 
 @fastmath -(0.5*log(2.0π) + 0.5*log(σ²) + abs2(x - μ)/(2.0 * σ²))




"""
  log-density of half-cauchy
"""
logdhcau(x::Float64, scl::Float64) = 
  @fastmath log(2 * scl/(π *(x * x + scl * scl)))




"""
  log-density of half-cauchy with scale 1
"""
logdhcau1(x::Float64) = 
  @fastmath log(2/(π * (x * x + 1)))




"""
  rejection sampling for each branch
  condition on start and end point
"""
function rejsam_cumsum(si::Int64, 
                       sf::Int64, 
                       λ1::Float64, 
                       λ0::Float64, 
                       t::Float64)
  
  evs, ssf = brprop_cumsum(si, λ1, λ0, t)

  while ssf != sf 
    evs, ssf = brprop_cumsum(si, λ1, λ0, t)
  end

  return evs
end





"""
  rejection sampling for each branch
  condition on start and end point
  for bit sampling
"""
function bit_rejsam!(bitv ::Array{Int64,1},
                     sf   ::Int64,
                     λ1   ::Float64, 
                     λ0   ::Float64, 
                     cumts::Array{Float64,1})
  
  bit_prop_hist!(bitv, λ1, λ0, cumts)

  while bitv[end] != sf 
    bit_prop_hist!(bitv, λ1, λ0, cumts)
  end

end





"""
  propose events for a branch
  with equal rates for gain and loss
  return the cumsum of times
  * Ugly code but slightly faster *
"""
function brprop_cumsum(si::Int64, λ1::Float64, λ0::Float64, t::Float64)

  cur_s::Int64            = si
  cur_t::Float64          = 0.
  cum_t::Array{Float64,1} = Float64[]

  if cur_s == 0
    cur_t += rexp(λ1)

    while cur_t < t
      push!(cum_t, cur_t)
      cur_s  = 1 - cur_s
      cur_t += rexp(λ0)
    
      if cur_t > t
        break
      end

      push!(cum_t, cur_t)
      cur_s  = 1 - cur_s
      cur_t += rexp(λ1)
    end

  else
    cur_t += rexp(λ0)

    while cur_t < t
      push!(cum_t, cur_t)
      cur_s  = 1 - cur_s
      cur_t += rexp(λ1)
    
      if cur_t > t
        break
      end

      push!(cum_t, cur_t)
      cur_s  = 1 - cur_s
      cur_t += rexp(λ0)
    end

  end

  push!(cum_t, t)

  return cum_t, cur_s
end




"""
  function for proposing bit histories 
  according to cumulative δtimes and assigning
  to bitv
  *Ugly code but slightly faster*
"""
function bit_prop_hist!(bitv ::Array{Int64,1},
                        λ1   ::Float64, 
                        λ0   ::Float64, 
                        cumts::Array{Float64,1})

  @fastmath begin

    lbitv = endof(bitv)::Int64
    cur_s = bitv[1]::Int64
    cur_t = 0.0
    s     = 2

    if cur_s == 0

      while true

        cur_t += rexp(λ1)::Float64
        f      = idxlessthan(cumts, cur_t)::Int64

        bitv[s:f] = cur_s
        
        if f == lbitv
          break
        end

        cur_s = 1 - cur_s
        s     = f + 1

        # same but with loss rate
        cur_t += rexp(λ0)::Float64
        f      = idxlessthan(cumts, cur_t)::Int64

        bitv[s:f] = cur_s

        if f == lbitv
          break
        end

        cur_s = 1 - cur_s
        s     = f + 1

      end

    else

      while true

        cur_t += rexp(λ0)::Float64
        f      = idxlessthan(cumts, cur_t)::Int64

        bitv[s:f] = cur_s
        
        if f == lbitv
          break
        end

        cur_s = 1 - cur_s
        s     = f + 1

        # same but with loss rate
        cur_t += rexp(λ1)::Float64
        f      = idxlessthan(cumts, cur_t)::Int64

        bitv[s:f] = cur_s

        if f == lbitv
          break
        end

        cur_s = 1 - cur_s
        s     = f + 1

      end
    end

  end
end





"""
  make ragged array with index for each edge in Yc
"""
function make_edgeind(childs::Array{Int64,1}, B::Array{Float64,2})

  bridx = Array{Int64,1}[]
  for b in childs
    push!(bridx, find(b .== B))
  end

  bridx
end



"""
  make ragged array of the cumulative delta times for each branch
"""
function make_edgeδt(bridx::Array{Array{Int64,1},1}, 
                     δt   ::Array{Float64,1}, 
                     m    ::Int64)
  
  brδt = Array{Float64,1}[]
  
  for j in 1:(length(bridx)-1)
    bi = copy(bridx[j] .- 1)
    for i in eachindex(bi)
      bi[i] = rowind(bi[i], m)
    end
    push!(brδt, cumsum(δt[bi]))
  end
  
  brδt
end





"""
  return index in vector "x" corresponding to a value 
  that is closest but smaller than "val" in sorted arrays 
  using a sort of uniroot algorithm
"""
function idxlessthan(x::Array{Float64,1}, val::Float64) 
  
  @inbounds begin

    a  ::Int64 = 1
    b  ::Int64 = endof(x)
  
    if x[b] < val
      return b
    end

    mid::Int64 = div(b,2)  

    while b-a > 1
      val < x[mid] ? b = mid : a = mid
      mid = div(b + a, 2)
    end

  end

  return a
end 






"""
  return index for closest value in sorted arrays 
  using a sort of uniroot algorithm
  FLOATS
"""
function indmindif_sorted(x::Array{Float64,1}, val::Float64) 
  a::Int64   = 1
  b::Int64   = endof(x)
  mid::Int64 = div(b,2)  

  while b-a > 1
    val < x[mid] ? b = mid : a = mid
    mid = div(b + a, 2)
  end

  abs(x[a] - val) < abs(x[b] - val) ? a : b
end 





"""
return index for closest value in sorted arrays 
using a sort of uniroot algorithm
INTEGERS
"""
function indmindif_sorted(x::Array{Int64,1}, val::Int64) 
  a::Int64   = 1
  b::Int64   = endof(x)
  mid::Int64 = div(b,2)  

  while b-a > 1
    val < x[mid] ? b = mid : a = mid
    mid = div(b + a, 2)
  end

  abs(x[a] - val) < abs(x[b] - val) ? a : b
end 




"""
  random exponential generator
"""
rexp(λ::Float64) = @fastmath log(rand()) * -(1/λ)





"""
  make branch triads:
  first number is the parent branch
  second and third numbers the daughters
"""
function maketriads(edges::Array{Int64,2})

  # internal nodes
  ins::Array{Int64,1} = unique(edges[:,1])[1:(end-1)]
  lins = length(ins)

  trios = Array{Int64,1}[]

  # for all internal nodes
  for i = Base.OneTo(lins)
    ndi  = ins[i]
    daus = find(edges[:,1] .== ndi)
    unshift!(daus, find(edges[:,2] .== ndi)[1])
    push!(trios, daus)
  end

  trios
end



"""
  function for sampling a coin flip 
  with non equal probilities
"""
coinsamp(p0::Float64) = rand() < p0 ? 0 : 1




"""
  normalize probabilities to 1
"""
normlize(pt1::Float64, pt2::Float64) = pt1/(pt1 + pt2)


@benchmark normlize(0.2,0.3)





"""
 =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
 For stem branch (continuous data augmentation)
 =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
"""




"""
  branch sampling for multiple areas,
  resampling if extinction is present
"""
function br_samp(ssii ::Array{Int64,1}, 
                 ssff ::Array{Int64,1},
                 λc   ::Array{Float64,2},
                 t    ::Float64,
                 narea::Int64)
  #time history
  t_hist = mult_rejsam(ssii, ssff, λc, t, narea)
  
  while ifext(t_hist, ssii, narea)
      t_hist = mult_rejsam(ssii, ssff, λc, t, narea)
  end

  t_hist
end





"""
  check if extinct
"""
function ifext(t_hist::Array{Array{Float64,1},1},
               ssii  ::Array{Int64,1}, 
               narea ::Int64)

  cs_hist = Float64[]
  hist_l  = Int64[]

  for i in eachindex(t_hist)
    append!(cs_hist, cumsum(t_hist[i]))
    append!(hist_l, fill(i,length(t_hist[i])))
  end

  # organize order of events
  sp  = sortperm(cs_hist)[1:(end - narea)]
  lhs = length(sp) + narea + 1

  # reconstruct state history
  s_hist = zeros(Int64, lhs,narea)
  for i in eachindex(ssii)
    s_hist[:,i] = ssii[i]
  end

  for i = eachindex(sp)
    setindex!(s_hist, 1 - s_hist[i,hist_l[sp[i]]], (i+1):lhs, hist_l[sp[i]])
  end

  # check if extinct
  for j = eachindex(sp)
    ss = 0
    for i = 1:narea
      ss += s_hist[j,i]
    end
    if ss == 0 
      return true
    end
  end

  return false
end




"""
  multistate branch sampling
"""
function mult_rejsam(ssii ::Array{Int64,1}, 
                     ssff ::Array{Int64,1},
                     λc   ::Array{Float64,2},
                     t    ::Float64,
                     narea::Int64)

  all_times = Array{Float64,1}[]

  for i in Base.OneTo(narea)
    push!(all_times, rejsam(ssii[i], ssff[i], λc[i,1], λc[i,2], t))
  end

  return all_times
end




"""
  rejection sampling for each branch
  condition on start and end point
"""
function rejsam(si::Int64, sf::Int64, λ1::Float64, λ0::Float64, t::Float64)
  
  sam::Tuple{Array{Float64,1},Int64} = brprop(si, λ1, λ0, t)
  
  while sam[2] != sf 
    sam = brprop(si, λ1, λ0, t)
  end

  return sam[1]
end




"""
  propose events for a branch
"""
function brprop(si::Int64, λ1::Float64, λ0::Float64, t::Float64)

  c_st   ::Int64            = si
  c_time ::Float64          = 0.0
  times  ::Array{Float64,1} = zeros(0)
  endtime::Float64          = t

  re::Float64 = c_st == 0 ? rexp(λ1) : rexp(λ0)

  c_time += re 

  while c_time < t
    push!(times, re)
    endtime  = t - c_time 
    c_st     = 1 - c_st
    re       = c_st == 0 ? rexp(λ1) : rexp(λ0)
    c_time  += re
  end

  push!(times, endtime)

  return times, c_st
end

