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

function _get_position(position, key::Symbol, default=nothing)
    if position isa Dict
        haskey(position, key) && return position[key]
        haskey(position, String(key)) && return position[String(key)]
        default !== nothing && return default
        error("Champ manquant: $(key)")
    end
    return getproperty(position, key)
end

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

function discount_factor_from_zc_price_curve(
    pillars::Vector{Float64},
    zc_prices::Vector{Float64},
    maturity::Real;
    zc_nominal::Float64=100.0,
)
    return interpolate_curve(pillars, zc_prices, maturity) / zc_nominal
end

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
            cashflow += nominal
        end
        df = discount_factor_from_zc_price_curve(
            pillars, zc_prices, t; zc_nominal=zc_nominal
        )
        price += cashflow * df
    end
    return price
end

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
        stressed_curve = current_zc_prices .* (1.0 .+ scenarios.values[i, :])
        value = compute_portfolio_initial_value(
            vec(stressed_curve), scenarios.pillars, portfolio; zc_nominal=zc_nominal
        )
        pnls[i] = value - initial
    end
    return pnls
end
