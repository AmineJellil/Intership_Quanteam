using Dates
using Statistics

# Sélectionne au plus `count` observations antérieures ou égales à la date
# demandée. Les indices conservent l'ordre chronologique de la courbe.
function _window_until(curve::CurveMatrix, date::Date, count::Int)
    idx = findall(d -> d <= date, curve.dates)
    isempty(idx) && error("Aucune observation avant $(date).")
    selected = idx[max(1, length(idx) - count + 1):end]
    return selected
end

"""
    compute_ewma_volatility(returns; lambda_ewma=0.94)

Calcule une volatilité conditionnelle par pilier selon la récurrence :
`sigma²_t = lambda × sigma²_(t-1) + (1-lambda) × r²_(t-1)`.

La variance initiale est fixée au carré du premier return disponible.
"""
function compute_ewma_volatility(returns::CurveMatrix; lambda_ewma::Float64=0.94)
    n, p = size(returns.values)
    variances = zeros(Float64, n, p)
    squared = returns.values .^ 2
    variances[1, :] .= squared[1, :]
    for i in 2:n
        # Le return de la veille alimente la volatilité connue à la date i.
        variances[i, :] .= lambda_ewma .* variances[i - 1, :] .+
                            (1.0 - lambda_ewma) .* squared[i - 1, :]
    end
    return CurveMatrix(returns.dates, returns.pillars, sqrt.(variances))
end

"""
    build_scaled_scenarios(returns, vol; t0, LP)

Construit les scénarios FHS récents et adapte chaque return historique au
régime de volatilité observé à `t0`. Le facteur symétrisé appliqué au pilier est
`(sigma_t + sigma_t0) / (2 × sigma_t)`.
"""
function build_scaled_scenarios(returns::CurveMatrix, vol::CurveMatrix;
    t0, LP::Int)
    target = _as_date(t0)
    selected = _window_until(returns, target, LP)
    idx_t0 = findfirst(==(target), vol.dates)
    idx_t0 === nothing && error("t0 absent de la matrice de volatilites.")

    sigma_t0 = reshape(vol.values[idx_t0, :], 1, :)
    sigma_t = vol.values[selected, :]
    unscaled = returns.values[selected, :]
    scaling = (sigma_t .+ sigma_t0) ./ (2.0 .* sigma_t)
    values = scaling .* unscaled
    labels = ["FHS_" * string(d) for d in returns.dates[selected]]
    return ScenarioMatrix(labels, returns.pillars, values)
end

"""
    build_unscaled_scenarios(returns; stress_start, stress_end)

Extrait sans rescaling tous les returns compris dans la fenêtre historique de
stress. Ces chocs conservent donc leur amplitude observée.
"""
function build_unscaled_scenarios(returns::CurveMatrix; stress_start, stress_end)
    start_date = _as_date(stress_start)
    end_date = _as_date(stress_end)
    selected = findall(d -> start_date <= d <= end_date, returns.dates)
    labels = ["HIST_STRESS_" * string(d) for d in returns.dates[selected]]
    return ScenarioMatrix(labels, returns.pillars, returns.values[selected, :])
end

# Produit un libellé stable pour une maturité, par exemple `5Y` ou `0p25Y`.
function _pillar_label(pillar::Real)
    value = Float64(pillar)
    if isapprox(value, round(value); atol=1e-10)
        return string(Int(round(value))) * "Y"
    end
    return replace(string(value), "." => "p") * "Y"
end

# Retourne le pilier disponible le plus proche d'une maturité demandée.
function _nearest_pillar_index(pillars::Vector{Float64}, target::Real)
    distances = abs.(pillars .- Float64(target))
    return argmin(distances)
end

"""
    build_extreme_historical_scenarios(returns; stress_start, stress_end,
                                       count=15, pillar_extremes=[...])

Construit un ensemble réduit de scénarios historiques extrêmes :

1. les `count` dates ayant le mouvement moyen de courbe le plus ample ;
2. la plus forte hausse et la plus forte baisse de chaque pilier demandé.

Une date sélectionnée par plusieurs critères n'est ajoutée qu'une seule fois.
"""
function build_extreme_historical_scenarios(returns::CurveMatrix;
    stress_start,
    stress_end,
    count::Int=15,
    pillar_extremes::Vector{Float64}=[0.25, 5.0, 10.0, 20.0, 30.0],
)
    start_date = _as_date(stress_start)
    end_date = _as_date(stress_end)
    selected = findall(d -> start_date <= d <= end_date, returns.dates)
    isempty(selected) && error("Aucun scenario historique dans la fenetre de stress.")

    kept = Int[]
    label_by_index = Dict{Int,String}()

    # Centralise la déduplication tout en conservant l'ordre de sélection.
    function add_scenario(global_index::Int, label::String)
        if !(global_index in kept)
            push!(kept, global_index)
            label_by_index[global_index] = label
        end
    end

    # Le mouvement moyen signé résume le déplacement global de la courbe à une date.
    signed_mean = vec(mean(returns.values[selected, :]; dims=2))
    ranking = sortperm(abs.(signed_mean); rev=true)
    for local_index in ranking[1:min(count, length(ranking))]
        global_index = selected[local_index]
        add_scenario(global_index, "HIST_MEAN_EXTREME_" * string(returns.dates[global_index]))
    end

    # Les extrêmes locaux complètent les mouvements moyens avec des chocs
    # concentrés sur des zones précises de la courbe.
    for requested_pillar in pillar_extremes
        pillar_index = _nearest_pillar_index(returns.pillars, requested_pillar)
        actual_pillar = returns.pillars[pillar_index]
        pillar_name = _pillar_label(actual_pillar)
        pillar_returns = returns.values[selected, pillar_index]

        up_global_index = selected[argmax(pillar_returns)]
        down_global_index = selected[argmin(pillar_returns)]

        add_scenario(
            up_global_index,
            "HIST_UP_" * pillar_name * "_" * string(returns.dates[up_global_index]),
        )
        add_scenario(
            down_global_index,
            "HIST_DOWN_" * pillar_name * "_" * string(returns.dates[down_global_index]),
        )
    end

    labels = [label_by_index[i] for i in kept]
    return ScenarioMatrix(labels, returns.pillars, returns.values[kept, :])
end
