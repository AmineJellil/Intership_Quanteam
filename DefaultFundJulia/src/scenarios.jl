using Dates

function _window_until(curve::CurveMatrix, date::Date, count::Int)
    idx = findall(d -> d <= date, curve.dates)
    isempty(idx) && error("Aucune observation avant $(date).")
    selected = idx[max(1, length(idx) - count + 1):end]
    return selected
end

function compute_ewma_volatility(returns::CurveMatrix; lambda_ewma::Float64=0.94)
    n, p = size(returns.values)
    variances = zeros(Float64, n, p)
    squared = returns.values .^ 2
    variances[1, :] .= squared[1, :]
    for i in 2:n
        variances[i, :] .= lambda_ewma .* variances[i - 1, :] .+
                            (1.0 - lambda_ewma) .* squared[i - 1, :]
    end
    return CurveMatrix(returns.dates, returns.pillars, sqrt.(variances))
end

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

function build_unscaled_scenarios(returns::CurveMatrix; stress_start, stress_end)
    start_date = _as_date(stress_start)
    end_date = _as_date(stress_end)
    selected = findall(d -> start_date <= d <= end_date, returns.dates)
    labels = ["HIST_STRESS_" * string(d) for d in returns.dates[selected]]
    return ScenarioMatrix(labels, returns.pillars, returns.values[selected, :])
end
