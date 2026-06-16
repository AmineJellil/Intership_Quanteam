using Statistics
using DataFrames
using DefaultFundJulia

repo_root = normpath(joinpath(@__DIR__, "..", ".."))
zc_path = joinpath(
    repo_root,
    "IM_pipeline.",
    "IM_pipeline",
    "data",
    "raw",
    "ZeroCouponCurve.csv",
)

config = ModelConfig(
    LP=2500,
    HP=5,
    SW=60,
    lambda_ewma=0.94,
    t0="2025-05-30",
    stress_start="2022-01-01",
    stress_end="2023-12-31",
    alpha=0.99,
    FHS_w=0.75,
    Stress_w=0.25,
    nominal=100.0,
)

members = Dict(
    "Membre_A" => [
        Dict(:name => "MOROCCO 2024 2.7% 19/01/26", :maturity => 0.92, :coupon_rate => 0.0270, :nominal => 100.0, :frequency => 1, :quantity => 250000.0),
        Dict(:name => "MOROCCO 2014 5.6% 16/04/29", :maturity => 4.16, :coupon_rate => 0.0560, :nominal => 100.0, :frequency => 1, :quantity => 180000.0),
        Dict(:name => "MOROCCO 2014 5.45% 06/08/29", :maturity => 4.47, :coupon_rate => 0.0545, :nominal => 100.0, :frequency => 1, :quantity => 220000.0),
        Dict(:name => "MOROCCO 2022 2.4% 14/06/32", :maturity => 7.33, :coupon_rate => 0.0240, :nominal => 100.0, :frequency => 1, :quantity => 80000.0),
        Dict(:name => "MOROCCO 2014 5.85% 31/03/34", :maturity => 9.12, :coupon_rate => 0.0585, :nominal => 100.0, :frequency => 1, :quantity => -50000.0),
    ],
    "Membre_B" => [
        Dict(:name => "MOROCCO 2014 5.6% 16/04/29", :maturity => 4.16, :coupon_rate => 0.0560, :nominal => 100.0, :frequency => 1, :quantity => 120000.0),
        Dict(:name => "MOROCCO 2014 5.45% 06/08/29", :maturity => 4.47, :coupon_rate => 0.0545, :nominal => 100.0, :frequency => 1, :quantity => -60000.0),
        Dict(:name => "MOROCCO 2022 2.4% 14/06/32", :maturity => 7.33, :coupon_rate => 0.0240, :nominal => 100.0, :frequency => 1, :quantity => 240000.0),
        Dict(:name => "MOROCCO 2014 5.85% 31/03/34", :maturity => 9.12, :coupon_rate => 0.0585, :nominal => 100.0, :frequency => 1, :quantity => 180000.0),
        Dict(:name => "MOROCCO 2021 3.45% 20/02/51", :maturity => 26.02, :coupon_rate => 0.0345, :nominal => 100.0, :frequency => 1, :quantity => 25000.0),
    ],
    "Membre_C" => [
        Dict(:name => "MOROCCO 2022 2.4% 14/06/32", :maturity => 7.33, :coupon_rate => 0.0240, :nominal => 100.0, :frequency => 1, :quantity => 90000.0),
        Dict(:name => "MOROCCO 2014 5.85% 31/03/34", :maturity => 9.12, :coupon_rate => 0.0585, :nominal => 100.0, :frequency => 1, :quantity => 130000.0),
        Dict(:name => "MOROCCO 2021 3.45% 20/02/51", :maturity => 26.02, :coupon_rate => 0.0345, :nominal => 100.0, :frequency => 1, :quantity => 100000.0),
        Dict(:name => "MOROCCO 2024 4.9% 15/02/55", :maturity => 30.01, :coupon_rate => 0.0490, :nominal => 100.0, :frequency => 1, :quantity => 220000.0),
        Dict(:name => "MOROCCO 2024 4 1/2% 19/04/55", :maturity => 30.19, :coupon_rate => 0.0450, :nominal => 100.0, :frequency => 1, :quantity => 250000.0),
    ],
    "Membre_D" => [
        Dict(:name => "MOROCCO 2014 5.45% 06/08/29", :maturity => 4.47, :coupon_rate => 0.0545, :nominal => 100.0, :frequency => 1, :quantity => 70000.0),
        Dict(:name => "MOROCCO 2014 5.85% 31/03/34", :maturity => 9.12, :coupon_rate => 0.0585, :nominal => 100.0, :frequency => 1, :quantity => 100000.0),
        Dict(:name => "MOROCCO 2021 3.45% 20/02/51", :maturity => 26.02, :coupon_rate => 0.0345, :nominal => 100.0, :frequency => 1, :quantity => 140000.0),
        Dict(:name => "MOROCCO 2024 4.9% 15/02/55", :maturity => 30.01, :coupon_rate => 0.0490, :nominal => 100.0, :frequency => 1, :quantity => 190000.0),
        Dict(:name => "MOROCCO 2024 4 1/2% 19/04/55", :maturity => 30.19, :coupon_rate => 0.0450, :nominal => 100.0, :frequency => 1, :quantity => 210000.0),
    ],
    "Membre_E" => [
        Dict(:name => "MOROCCO 2024 2.7% 19/01/26", :maturity => 0.92, :coupon_rate => 0.0270, :nominal => 100.0, :frequency => 1, :quantity => 200000.0),
        Dict(:name => "MOROCCO 2014 5.6% 16/04/29", :maturity => 4.16, :coupon_rate => 0.0560, :nominal => 100.0, :frequency => 1, :quantity => 100000.0),
        Dict(:name => "MOROCCO 2022 2.4% 14/06/32", :maturity => 7.33, :coupon_rate => 0.0240, :nominal => 100.0, :frequency => 1, :quantity => -80000.0),
        Dict(:name => "MOROCCO 2021 3.45% 20/02/51", :maturity => 26.02, :coupon_rate => 0.0345, :nominal => 100.0, :frequency => 1, :quantity => 120000.0),
        Dict(:name => "MOROCCO 2024 4.9% 15/02/55", :maturity => 30.01, :coupon_rate => 0.0490, :nominal => 100.0, :frequency => 1, :quantity => 160000.0),
    ],
    "Membre_F" => [
        Dict(:name => "MOROCCO 2024 2.7% 19/01/26", :maturity => 0.92, :coupon_rate => 0.0270, :nominal => 100.0, :frequency => 1, :quantity => -150000.0),
        Dict(:name => "MOROCCO 2014 5.6% 16/04/29", :maturity => 4.16, :coupon_rate => 0.0560, :nominal => 100.0, :frequency => 1, :quantity => 180000.0),
        Dict(:name => "MOROCCO 2014 5.45% 06/08/29", :maturity => 4.47, :coupon_rate => 0.0545, :nominal => 100.0, :frequency => 1, :quantity => 130000.0),
        Dict(:name => "MOROCCO 2014 5.85% 31/03/34", :maturity => 9.12, :coupon_rate => 0.0585, :nominal => 100.0, :frequency => 1, :quantity => -140000.0),
        Dict(:name => "MOROCCO 2021 3.45% 20/02/51", :maturity => 26.02, :coupon_rate => 0.0345, :nominal => 100.0, :frequency => 1, :quantity => 60000.0),
        Dict(:name => "MOROCCO 2024 4 1/2% 19/04/55", :maturity => 30.19, :coupon_rate => 0.0450, :nominal => 100.0, :frequency => 1, :quantity => 100000.0),
    ],
)

println("Chargement des donnees ZC...")
zc_rates = load_zero_coupon_curve(zc_path)
zc_prices = build_zero_coupon_price_matrix(zc_rates; nominal=config.nominal)
returns = compute_historical_returns(zc_prices; HP=config.HP)
vol = compute_ewma_volatility(returns; lambda_ewma=config.lambda_ewma)

scaled_fhs = build_scaled_scenarios(returns, vol; t0=config.t0, LP=config.LP)
historical_stress = build_unscaled_scenarios(
    returns;
    stress_start=config.stress_start,
    stress_end=config.stress_end,
)

println("Construction des scenarios ACP hypothetiques...")
pca_model = fit_pca_stress(returns; n_components=3)
acp_hypothetical = build_quantile_hypothetical_scenarios(
    pca_model; quantile_level=0.995
)

stress_scenarios = concat_scenarios(historical_stress, acp_hypothetical)
current_zc_prices = row_at(zc_prices, config.t0)

member_names = collect(keys(members))
sort!(member_names)

pnl_fhs = zeros(Float64, length(scaled_fhs.labels), length(member_names))
pnl_stress = zeros(Float64, length(stress_scenarios.labels), length(member_names))
initial_values = zeros(Float64, length(member_names))

for (j, member) in enumerate(member_names)
    portfolio = members[member]
    initial_values[j] = compute_portfolio_initial_value(
        current_zc_prices, zc_prices.pillars, portfolio; zc_nominal=config.nominal
    )
    pnl_fhs[:, j] = compute_portfolio_pnl_under_scenarios(
        current_zc_prices, scaled_fhs, portfolio; zc_nominal=config.nominal
    )
    pnl_stress[:, j] = compute_portfolio_pnl_under_scenarios(
        current_zc_prices, stress_scenarios, portfolio; zc_nominal=config.nominal
    )
end

es_fhs = [compute_es_from_pnl(pnl_fhs[:, j]; alpha=config.alpha) for j in eachindex(member_names)]
es_stress = [compute_es_from_pnl(pnl_stress[:, j]; alpha=config.alpha) for j in eachindex(member_names)]
initial_margin = config.FHS_w .* es_fhs .+ config.Stress_w .* es_stress

stress_losses = losses_from_pnl(pnl_stress)
sloim = compute_sloim(stress_losses, initial_margin)
cover2_by_scenario = compute_cover2_by_scenario(
    sloim,
    stress_scenarios.labels,
    member_names,
)

binding_idx = argmax(cover2_by_scenario.cover2_requirement)
default_fund_cover2 = cover2_by_scenario.cover2_requirement[binding_idx]

println()
println("Scenarios FHS: ", size(pnl_fhs, 1))
println("Scenarios stress historiques: ", length(historical_stress.labels))
println("Scenarios stress ACP: ", length(acp_hypothetical.labels))
println("Scenarios stress totaux: ", length(stress_scenarios.labels))
println()
println("Scenario contraignant: ", cover2_by_scenario.scenario[binding_idx])
println("Premier membre: ", cover2_by_scenario.first_member[binding_idx])
println("Deuxieme membre: ", cover2_by_scenario.second_member[binding_idx])
println("Fonds Cover-2 brut: ", round(default_fund_cover2; digits=2))

allocation = allocate_default_fund(
    default_fund_cover2 * 1.10,
    initial_margin;
    minimum_share=0.02,
)
allocation.member = member_names
println()
println(allocation[:, [:member, :risk_weight, :total_contribution, :final_share]])
