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
    losses = max.(-Float64.(collect(pnl)), 0.0)
    return compute_expected_shortfall(losses; alpha=alpha)
end


function compute_initial_margin(
    es_fhs::Real,
    es_stress::Real;
    fhs_w::Float64=0.75,
    stress_w::Float64=0.25,
)
    es_hybrid = fhs_w * Float64(es_fhs) + stress_w * Float64(es_stress)
    return max(Float64(es_fhs), es_hybrid)
end
