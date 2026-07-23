"""
    DefaultFundJulia

Moteur de risque pour construire des scénarios de courbe ZC, revaloriser des
portefeuilles obligataires et dimensionner un fonds de défaut Cover-2.

Le module regroupe les briques utilisées par le notebook principal. Les
fichiers sont inclus dans l'ordre de leurs dépendances : types et configuration
d'abord, calculs de marché et de risque ensuite, puis SLOIM et Cover-2.
"""
module DefaultFundJulia

# Types partagés et paramètres du modèle.
include("data_types.jl")
include("config.jl")

# Données de marché, facteurs de risque et scénarios.
include("market_data.jl")
include("risk_factors.jl")
include("scenarios.jl")

# Valorisation, mesures de risque et stress ACP.
include("pricing.jl")
include("risk_measures.jl")
include("pca_stress.jl")
include("monia.jl")

# Pertes résiduelles et dimensionnement du fonds de défaut.
include("default_fund.jl")

# Configuration et conteneurs matriciels.
export ModelConfig
export CurveMatrix, ScenarioMatrix

# Chargement de données et construction des facteurs de risque.
export load_zero_coupon_curve, clean_zero_coupon_curve, row_at
export build_zero_coupon_price_matrix, compute_historical_returns
export compute_litterman_zero_returns

# Scénarios historiques, FHS et opérations sur les matrices de scénarios.
export compute_ewma_volatility, build_scaled_scenarios, build_unscaled_scenarios
export build_extreme_historical_scenarios
export concat_scenarios, as_scenarios

# Valorisation obligataire et PnL.
export price_fixed_rate_bond_from_zc_prices, compute_portfolio_initial_value
export compute_portfolio_pnl_under_scenarios

# Expected Shortfall, marge initiale et stress ACP.
export compute_expected_shortfall, compute_es_from_pnl, compute_initial_margin
export PCAStressModel, fit_pca_stress, standardized_scores

# Fonctions exploratoires liées au taux MONIA.
export MoniaSeries, load_monia, monia_summary
export build_monia_aligned_returns, build_monia_excess_returns

# Constructeurs de scénarios hypothétiques ACP.
export build_quantile_hypothetical_scenarios
export build_grid_hypothetical_scenarios
export build_tail_hypothetical_scenarios
export compute_pc_tail_quantiles

# Pertes stressées, SLOIM et Cover-2.
export losses_from_pnl, compute_sloim, compute_cover2_by_scenario

end
