"""
    build_zero_coupon_price_matrix(curve; nominal=100.0)

Convertit une courbe de taux ZC en prix ZC par capitalisation composée :
`P(t, T) = nominal / (1 + y(t, T))^T`.
"""
function build_zero_coupon_price_matrix(curve::CurveMatrix; nominal::Float64=100.0)
    powers = reshape(curve.pillars, 1, :)
    values = nominal ./ ((1 .+ curve.values) .^ powers)
    return CurveMatrix(curve.dates, curve.pillars, values)
end

"""
    compute_historical_returns(price_curve; HP)

Calcule les returns relatifs de prix sur `HP` observations :
`R(t, T) = P(t, T) / P(t-HP, T) - 1`.

La matrice retournée perd les `HP` premières dates, qui ne disposent pas d'un
point de comparaison antérieur.
"""
function compute_historical_returns(price_curve::CurveMatrix; HP::Int)
    HP > 0 || error("HP doit etre strictement positif.")
    n = size(price_curve.values, 1)
    n > HP || error("Pas assez de donnees pour calculer les returns.")
    values = price_curve.values[(HP + 1):end, :] ./ price_curve.values[1:(end - HP), :] .- 1.0
    dates = price_curve.dates[(HP + 1):end]
    return CurveMatrix(dates, price_curve.pillars, values)
end

"""
    compute_litterman_zero_returns(yield_curve; HP)

Approxime le return d'un ZC par la relation de premier ordre
`R(t, T) ≈ -T × (y(t, T) - y(t-HP, T))`.

Cette pondération par la maturité rend les variations de taux comparables en
termes d'impact de prix et fournit la matrice utilisée par l'ACP de stress.
"""
function compute_litterman_zero_returns(yield_curve::CurveMatrix; HP::Int)
    HP > 0 || error("HP doit etre strictement positif.")
    n = size(yield_curve.values, 1)
    n > HP || error("Pas assez de donnees pour calculer les returns.")

    yield_changes = yield_curve.values[(HP + 1):end, :] .- yield_curve.values[1:(end - HP), :]
    maturities = reshape(yield_curve.pillars, 1, :)
    # Le signe négatif traduit la relation inverse entre taux et prix ZC.
    values = -maturities .* yield_changes
    dates = yield_curve.dates[(HP + 1):end]

    return CurveMatrix(dates, yield_curve.pillars, values)
end
