using Statistics

# Détermine le nombre d'observations de queue. L'arrondi préalable évite les
# erreurs numériques autour d'un entier théorique, puis `ceil` reste prudent.
function _safe_tail_size(alpha::Real, n::Integer)
    raw = (1.0 - Float64(alpha)) * n
    return max(1, ceil(Int, round(raw; digits=12)))
end

"""
    compute_expected_shortfall(losses; alpha=0.99)

Trie les pertes de la plus forte à la plus faible et retourne la moyenne des
`ceil((1-alpha) × n)` observations les plus sévères. Au moins une observation
est toujours retenue.
"""
function compute_expected_shortfall(losses::AbstractVector; alpha::Float64=0.99)
    clean = sort(collect(skipmissing(losses)); rev=true)
    n = length(clean)
    n == 0 && error("Serie de pertes vide.")
    k = _safe_tail_size(alpha, n)
    return mean(clean[1:k])
end

"""
    compute_es_from_pnl(pnl; alpha=0.99)

Convertit les PnL en pertes non négatives, puis calcule leur Expected
Shortfall. Un ensemble de scénarios tous gagnants produit ainsi une ES nulle.
"""
function compute_es_from_pnl(pnl::AbstractVector; alpha::Float64=0.99)
    losses = max.(-Float64.(collect(pnl)), 0.0)
    return compute_expected_shortfall(losses; alpha=alpha)
end

"""
    compute_initial_margin(es_fhs, es_stress; fhs_w=0.75, stress_w=0.25)

Agrège les composantes FHS et stress, puis applique le plancher FHS :

`ES_hybrid = fhs_w × ES_FHS + stress_w × ES_stress`

`IM = max(ES_FHS, ES_hybrid)`.
"""
function compute_initial_margin(
    es_fhs::Real,
    es_stress::Real;
    fhs_w::Float64=0.75,
    stress_w::Float64=0.25,
)
    es_hybrid = fhs_w * Float64(es_fhs) + stress_w * Float64(es_stress)
    return max(Float64(es_fhs), es_hybrid)
end
