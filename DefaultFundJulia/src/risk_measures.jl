using Statistics

function _safe_tail_size(alpha::Real, n::Integer)
    raw = (1.0 - Float64(alpha)) * n
    return max(1, ceil(Int, round(raw; digits=12)))
end

function compute_expected_shortfall(losses::AbstractVector; alpha::Float64=0.99)
    clean = sort(collect(skipmissing(losses)); rev=true)
    n = length(clean)
    n == 0 && error("Serie de pertes vide.")
    k = _safe_tail_size(alpha, n)
    return mean(clean[1:k])
end

function compute_es_from_pnl(pnl::AbstractVector; alpha::Float64=0.99)
    return compute_expected_shortfall(-collect(pnl); alpha=alpha)
end
