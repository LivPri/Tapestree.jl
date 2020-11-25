#=

ESSE marginal ancestral estate probabilities

Ignacio Quintero Mächler

t(-_-t)

September 26 2017

=#



"""
make node to root path to only integrate over those equations.
"""




"""
"""
function nodetoroot_triads(ed   ::Array{Int64,2},
                           trios::Array{Array{Int64,1},1})

  ed2 = ed[:,2]

  tdic = Array{Tuple{Array{Int64,1},Int64},1}[]

  for i in Base.OneTo(size(ed,1))

    # make node-to-root path
    ndic = Int64[] 

    n = i
    while true
      push!(ndic, n)
      pr, da = ed[n,:]
      n = findfirst(isequal(pr), ed2)
      if isnothing(n)
        break
      end
    end

    # determine trios where the nodes in ndic are
    tdicn = Tuple{Array{Int64,1},Int64}[]
    for n in ndic, t in trios
      @views pos = findfirst(isequal(n), t[2:3])
      if !isnothing(pos)
        push!(tdicn, (t, pos))
      end
    end

    push!(tdic, tdicn)
  end

  return tdic
end


tdic = nodetoroot_triads(ed, trios)


Xfix = deepcopy(X)

for i in Base.OneTo(length(X))
  unsafe_copyto!(X[i], Xfix[])
end


p[1] = rand(24)

llf(p[1])
llx = X[99][1:ns]

ll = zeros(6)
for i in 1:ns
  ll[i] = llfnj(p[1],99,i)
end

# if root
ll ./ (sum(ll))

exp.(ll) ./ (sum(exp.(ll)))
llx

# exp(l1)/(exp(l2) + exp(l1))

# exp(l2)/(exp(l2) + exp(l1))

# exp(l2)/exp(l1)
# exp(l1)/exp(l2)

# l1 - l2
# l2 - l1








"""
    make_loglik_nj(X        ::Array{Array{Float64,1},1},
                   abts1    ::Array{Float64,1},
                   abts2    ::Array{Float64,1},
                   trios    ::Array{Array{Int64,1},1},
                   int      ::DiffEqBase.DEIntegrator,
                   λevent!  ::Function, 
                   rootll   ::Function,
                   ns       ::Int64,
                   ned      ::Int64)

Make likelihood function for tree and tip states following an ODE function 
where node `n` has state `j`.
"""
function make_loglik_nj(X         ::Array{Array{Float64,1},1},
                        tdic      ::Array{Array{Tuple{Array{Int64,1},Int64},1},1},
                        abts1     ::Array{Float64,1},
                        abts2     ::Array{Float64,1},
                        trios     ::Array{Array{Int64,1},1},
                        int       ::DiffEqBase.DEIntegrator,
                        λevent!   ::Function, 
                        rootll_nj!::Function,
                        ns        ::Int64,
                        ned       ::Int64)

  # preallocate vectors
  llik = Array{Float64,1}(undef, ns)
  w    = Array{Float64,1}(undef, ns)
  extp = Array{Float64,1}(undef, ns)

  function f(p   ::Array{Float64,1}, 
             n   ::Int64, 
             j   ::Int64, 
             Xfix::Array{Array{Float64,1},1})

    @inbounds begin

      int.p = p

      llxtra = 0.0

      tdicn = tdic[n]

      # copy from fix
      @simd for i in Base.OneTo(ned)
        unsafe_copyto!(X[i], 1, Xfix[i], 1, ns)
      end

      # make node likelihood `0.0` to all other states
      for i in Base.OneTo(ns)
        i == j && continue
        X[n][i] = 0.0
      end

      # loop for integrating over internal branches from node-to-root
      for (triad, pos) in tdicn

        pr, d1, d2 = triad

        ud1 = @views solvef(int, X[d1], abts2[d1], abts1[d1])::Array{Float64,1}
        check_negs(ud1, ns) && return -Inf

        # ud1fix = @views solvef(int, X[d1], abts2[d1], abts1[d1])::Array{Float64,1}
        # check_negs(ud1, ns) && return -Inf


        ud2 = @views solvef(int, X[d2], abts2[d2], abts1[d2])::Array{Float64,1}
        check_negs(ud2, ns) && return -Inf

        #=
        perhaps have to recompute as well for Xfix to know the difference 
        in likelihoods
        =#

        # update likelihoods with speciation event
        λevent!(abts2[pr], llik, ud1, ud2, p)

        # loglik to sum for integration
        tosum = normbysum!(llik, ns)

        llxtra += log(tosum)

        # assign the remaining likelihoods &
        # assign extinction probabilities and 
        # check for extinction of `1.0`
        @views Xpr = X[pr]
        for i in Base.OneTo(ns)
          ud1[i+ns] >= 1.0 && return -Inf
          Xpr[i+ns] = ud1[i+ns]
          Xpr[i]    = llik[i]
        end
      end

      # assign root likelihood in non log terms &
      # assign root extinction probabilities
      @views Xned = X[ned]
      for i in Base.OneTo(ns)
        Xned[i+ns] >= 1.0 && return -Inf
        llik[i] = Xned[i]
        extp[i] = Xned[i+ns]
      end

      # estimate likelihood weights
      normbysum!(llik, w, ns)

      # combine root likelihoods
      rootll_nj!(abts1[ned], llik, extp, w, p)

      if n == ned
        return llik[j]::Float64
      else
        return (log(sum(llik)) + llxtra)::Float64
      end
    end
  end

  return f
end







"""
    rootll_full_nj(t   ::Float64,
                   llik::Array{Float64,1},
                   extp::Array{Float64,1},
                   w   ::Array{Float64,1},
                   p   ::Array{Float64,1},
                   λts ::Array{Float64,1},
                   r   ::Array{Float64,1},
                   af! ::Function,
                   ::Type{Val{k}},
                   ::Type{Val{h}},
                   ::Type{Val{ny}},
                   ::Type{Val{model}})::Float64 where {k, h, ny, model}

Generated function for full tree likelihood at the root for 
**pruning** likelihoods that returns a vector for each state.
"""
@generated function rootll_full_nj(t   ::Float64,
                                   llik::Array{Float64,1},
                                   extp::Array{Float64,1},
                                   w   ::Array{Float64,1},
                                   p   ::Array{Float64,1},
                                   λts ::Array{Float64,1},
                                   r   ::Array{Float64,1},
                                   af! ::Function,
                                   ::Type{Val{k}},
                                   ::Type{Val{h}},
                                   ::Type{Val{ny}},
                                   ::Type{Val{model}})::Float64 where {k, h, ny, model}

  S = create_states(k, h)

  eqs = quote end
  popfirst!(eqs.args)

  if model[1]

    # last non β parameters
    bbase = isone(k) ? 
      (2h + h*(h-1)) : (h*(k+1) + 2*k*h + k*(k-1)*h + h*(h-1))

    # ncov
    ncov = model[1]*k + model[2]*k + model[3]*k*(k-1)

    # y per parameter
    yppar = isone(ny) ? 1 : ceil(Int64,ny/ncov)

    # add environmental function
    push!(eqs.args, :(af!(t, r)))

    isone(ny) && push!(eqs.args, :(r1 = r[1]))

    for j = Base.OneTo(h), i = Base.OneTo(k)
      coex = Expr(:call, :+)
      for yi in Base.OneTo(yppar)
        rex = isone(ny) ? :(r1) : :(r[$(yi+yppar*(i-1))])
        push!(coex.args, :(p[$(bbase + yi + yppar*((i-1) + k*(j-1)))] * $rex))
      end
      if isone(k)
        push!(eqs.args, :(λts[$(i + (j-1))] = p[$(i + (j-1))]*exp($coex)))
      else
        push!(eqs.args, :(λts[$(i + k*(j-1))] = p[$(i + (k+1)*(j-1))]*exp($coex)))
      end
    end

    eq = quote end
    popfirst!(eq.args)
    for j in Base.OneTo(h)
      # for single areas
      for i in Base.OneTo(k)
        push!(eq.args,
          :(llik[$(i + (2^k-1)*(j-1))] *= 
            w[$(i + (2^k-1)*(j-1))] / 
            (λts[$(i + k*(j-1))]*(1.0-extp[$(i + (j-1)*(2^k-1))])^2)))
      end
      # for widespread
      for i in k+1:2^k-1
        wl = :(llik[$(i + (2^k-1)*(j-1))] *= 
               w[$(i + (2^k-1)*(j-1))] /(le))

        lams = Expr(:call, :+)
        # single area speciation
        for a in S[i + (2^k-1)*(j-1)].g
          push!(lams.args, :(
            λts[$(a + k*(j-1))] * 
           (1.0-extp[$(a + (j-1)*(2^k-1))]) * (1.0-extp[$(i + (j-1)*(2^k-1))])))
        end

        # for allopatric speciation
        for (la, ra) = vicsubsets(S[i + (2^k-1)*(j-1)].g)[1:(div(end,2))]
          push!(lams.args, 
            :(p[$((k+1)*(1+(j-1)))] *
             (1.0-extp[$(findfirst(x -> isequal(ra,x.g), S) + (2^k-1)*(j-1))]) * 
             (1.0-extp[$(findfirst(x -> isequal(la,x.g), S) + (2^k-1)*(j-1))])))
        end

        # change le in wl
        wl.args[2].args[3] = lams

        push!(eq.args, wl)
      end
    end

  # not speciation model
  else

    eq = quote end
    popfirst!(eq.args)
    for j in Base.OneTo(h)
      # for single areas
      for i in Base.OneTo(k)
        if isone(k)
          push!(eq.args,
            :(llik[$(i + (2^k-1)*(j-1))] *= 
              w[$(i + (2^k-1)*(j-1))] / 
              (p[$(i + (j-1))]*(1.0-extp[$(i + (j-1)*(2^k-1))])^2)))
        else
          push!(eq.args,
            :(llik[$(i + (2^k-1)*(j-1))] *= 
              w[$(i + (2^k-1)*(j-1))] / 
              (p[$(i + (k+1)*(j-1))]*(1.0-extp[$(i + (j-1)*(2^k-1))])^2)))
        end
      end
      # for widespread
      for i in k+1:2^k-1
        wl = :(llik[$(i + (2^k-1)*(j-1))] *= 
               w[$(i + (2^k-1)*(j-1))] /(le))

        lams = Expr(:call, :+)
        # single area speciation
        for a in S[i + (2^k-1)*(j-1)].g
          push!(lams.args, :(
            p[$(a + (k+1)*(j-1))] * 
           (1.0-extp[$(a + (j-1)*(2^k-1))]) * (1.0-extp[$(i + (j-1)*(2^k-1))])))
        end

        # for allopatric speciation
        for (la, ra) = vicsubsets(S[i + (2^k-1)*(j-1)].g)[1:(div(end,2))]
          push!(lams.args, 
            :(p[$((k+1)*(1+(j-1)))] *
             (1.0-extp[$(findfirst(x -> isequal(ra,x.g), S) + (2^k-1)*(j-1))]) * 
             (1.0-extp[$(findfirst(x -> isequal(la,x.g), S) + (2^k-1)*(j-1))])))
        end

        # change l in wl
        wl.args[2].args[3] = lams

        push!(eq.args, wl)
      end
    end
  end

  push!(eqs.args, :($eq))

  @debug eqs

  return quote
    @inbounds begin
      $eqs
    end
  end
end






"""
    make_rootll_nj(::Type{Val{h}}, 
                   ::Type{Val{k}}, 
                   ::Type{Val{ny}}, 
                   ::Type{Val{model}},
                   af!  ::Function) where {h, k, ny, model}

Make root conditioning likelihood function.
"""
function make_rootll_nj(::Type{Val{h}}, 
                        ::Type{Val{k}}, 
                        ::Type{Val{ny}}, 
                        ::Type{Val{model}},
                        af!  ::Function) where {h, k, ny, model}

  λts = Array{Float64,1}(undef,h*k)
  r   = Array{Float64,1}(undef,ny)

  rootll = let r = r, λts = λts, af! = af!
      (t   ::Float64,
              llik::Array{Float64,1},
              extp::Array{Float64,1},
              w   ::Array{Float64,1},
              p   ::Array{Float64,1}) -> 
      begin
        rootll_full_nj(t, llik, extp, w, p, λts, r, af!,
          Val{k}, Val{h}, Val{ny}, Val{model})::Float64
      end
  end
  
  return rootll
end



