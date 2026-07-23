function build_zero_coupon_price_matrix(curve::CurveMatrix; nominal::Float64=100.0)
    powers = reshape(curve.pillars, 1, :)
    values = nominal ./ ((1 .+ curve.values) .^ powers)
    return CurveMatrix(curve.dates, curve.pillars, values)
end

function compute_historical_returns(price_curve::CurveMatrix; HP::Int)
    HP > 0 || error("HP doit etre strictement positif.")
    n = size(price_curve.values, 1)
    n > HP || error("Pas assez de donnees pour calculer les returns.")
    values = price_curve.values[(HP + 1):end, :] ./ price_curve.values[1:(end - HP), :] .- 1.0
    dates = price_curve.dates[(HP + 1):end]
    return CurveMatrix(dates, price_curve.pillars, values)
end

function compute_litterman_zero_returns(yield_curve::CurveMatrix; HP::Int)
    HP > 0 || error("HP doit etre strictement positif.")
    n = size(yield_curve.values, 1)
    n > HP || error("Pas assez de donnees pour calculer les returns.")

    yield_changes = yield_curve.values[(HP + 1):end, :] .- yield_curve.values[1:(end - HP), :]
    maturities = reshape(yield_curve.pillars, 1, :)
    values = -maturities .* yield_changes
    dates = yield_curve.dates[(HP + 1):end]

    return CurveMatrix(dates, yield_curve.pillars, values)
end
