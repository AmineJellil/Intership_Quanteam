"""
    interpolate_curve(pillars, values, maturity)

Interpole linéairement une valeur entre les deux piliers qui encadrent la
maturité. En dehors de la grille, la valeur du pilier extrême est prolongée.
"""
function interpolate_curve(pillars::Vector{Float64}, values::Vector{Float64}, maturity::Real)
    t = Float64(maturity)
    t <= pillars[1] && return values[1]
    t >= pillars[end] && return values[end]

    upper = findfirst(x -> x >= t, pillars)
    lower = upper - 1
    x0, x1 = pillars[lower], pillars[upper]
    y0, y1 = values[lower], values[upper]
    alpha = (t - x0) / (x1 - x0)
    return (1.0 - alpha) * y0 + alpha * y1
end

# Uniformise l'accès aux positions décrites soit par un `Dict`, soit par une
# structure possédant des propriétés. Les dictionnaires peuvent avoir des clés
# `Symbol` ou `String`.
function _get_position(position, key::Symbol, default=nothing)
    if position isa Dict
        haskey(position, key) && return position[key]
        haskey(position, String(key)) && return position[String(key)]
        default !== nothing && return default
        error("Champ manquant: $(key)")
    end
    return getproperty(position, key)
end

# Construit les échéances de coupon en remontant depuis la maturité résiduelle.
# Cette convention permet de représenter les obligations dont la prochaine
# échéance n'est pas située exactement à un nombre entier d'années.
function _payment_times(maturity::Real, frequency::Integer)
    dt = 1.0 / frequency
    times = Float64[]
    t = Float64(maturity)
    while t > 1e-6
        push!(times, t)
        t -= dt
    end
    return sort(times)
end

"""
    discount_factor_from_zc_price_curve(pillars, zc_prices, maturity;
                                        zc_nominal=100.0)

Interpole le prix du ZC à la maturité demandée et le divise par son nominal
pour obtenir le facteur d'actualisation `DF(0, T)`.
"""
function discount_factor_from_zc_price_curve(
    pillars::Vector{Float64},
    zc_prices::Vector{Float64},
    maturity::Real;
    zc_nominal::Float64=100.0,
)
    return interpolate_curve(pillars, zc_prices, maturity) / zc_nominal
end

"""
    price_fixed_rate_bond_from_zc_prices(pillars, zc_prices, position;
                                         zc_nominal=100.0)

Valorise une obligation à taux fixe en actualisant séparément chaque coupon et
le remboursement final du nominal sur la courbe de prix ZC.

La position doit fournir `maturity` et `coupon_rate`. `nominal` et `frequency`
sont optionnels et valent respectivement `100` et `1` par défaut.
"""
function price_fixed_rate_bond_from_zc_prices(
    pillars::Vector{Float64},
    zc_prices::Vector{Float64},
    position;
    zc_nominal::Float64=100.0,
)
    maturity = Float64(_get_position(position, :maturity))
    coupon_rate = Float64(_get_position(position, :coupon_rate))
    nominal = Float64(_get_position(position, :nominal, 100.0))
    frequency = Int(_get_position(position, :frequency, 1))

    coupon = nominal * coupon_rate / frequency
    times = _payment_times(maturity, frequency)
    price = 0.0
    for (i, t) in enumerate(times)
        cashflow = coupon
        if i == length(times)
            # Le dernier flux contient le coupon et le remboursement du nominal.
            cashflow += nominal
        end
        df = discount_factor_from_zc_price_curve(
            pillars, zc_prices, t; zc_nominal=zc_nominal
        )
        price += cashflow * df
    end
    return price
end

"""
    price_bond_position_from_zc_prices(pillars, zc_prices, position;
                                       zc_nominal=100.0)

Multiplie le prix unitaire de l'obligation par sa quantité. Une quantité
négative représente une position courte et produit une valeur signée.
"""
function price_bond_position_from_zc_prices(
    pillars::Vector{Float64},
    zc_prices::Vector{Float64},
    position;
    zc_nominal::Float64=100.0,
)
    quantity = Float64(_get_position(position, :quantity, 1.0))
    unit_price = price_fixed_rate_bond_from_zc_prices(
        pillars, zc_prices, position; zc_nominal=zc_nominal
    )
    return quantity * unit_price
end

"""
    compute_portfolio_initial_value(current_zc_prices, pillars, portfolio;
                                    zc_nominal=100.0)

Somme les valeurs signées de toutes les positions obligataires du portefeuille.
"""
function compute_portfolio_initial_value(
    current_zc_prices::Vector{Float64},
    pillars::Vector{Float64},
    portfolio;
    zc_nominal::Float64=100.0,
)
    return sum(
        price_bond_position_from_zc_prices(
            pillars, current_zc_prices, pos; zc_nominal=zc_nominal
        )
        for pos in portfolio
    )
end

"""
    compute_portfolio_pnl_under_scenarios(current_zc_prices, scenarios,
                                          portfolio; zc_nominal=100.0)

Effectue une revalorisation complète du portefeuille sous chaque scénario.
Chaque choc relatif est appliqué au prix ZC courant :
`P_s(T_k) = P_0(T_k) × (1 + R_s(T_k))`.

Le résultat contient un PnL par scénario, calculé comme `V_s - V_0`.
"""
function compute_portfolio_pnl_under_scenarios(
    current_zc_prices::Vector{Float64},
    scenarios::ScenarioMatrix,
    portfolio;
    zc_nominal::Float64=100.0,
)
    initial = compute_portfolio_initial_value(
        current_zc_prices, scenarios.pillars, portfolio; zc_nominal=zc_nominal
    )
    pnls = zeros(Float64, length(scenarios.labels))
    for i in eachindex(scenarios.labels)
        # Tous les instruments du portefeuille sont revalorisés sur la même
        # courbe stressée afin de préserver la dépendance entre leurs cash-flows.
        stressed_curve = current_zc_prices .* (1.0 .+ scenarios.values[i, :])
        value = compute_portfolio_initial_value(
            vec(stressed_curve), scenarios.pillars, portfolio; zc_nominal=zc_nominal
        )
        pnls[i] = value - initial
    end
    return pnls
end
