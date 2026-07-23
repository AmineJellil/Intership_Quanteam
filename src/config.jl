using Dates

# Normalise les dates reçues depuis les CSV, le notebook ou un appel direct.
# Les chaînes simples et les horodatages `yyyy-mm-dd HH:MM:SS` sont acceptés.
function _as_date(x)
    x isa Date && return x
    x isa DateTime && return Date(x)
    s = String(x)
    try
        return Date(s)
    catch
        return Date(DateTime(s, dateformat"yyyy-mm-dd HH:MM:SS"))
    end
end

"""
    ModelConfig

Paramètres communs aux calculs de marge initiale et de stress.

Champs principaux :
- `LP` : nombre de scénarios récents de la fenêtre FHS ;
- `HP` : horizon historique, exprimé en nombre d'observations ;
- `SW` : taille de la fenêtre courte de volatilité ;
- `lambda_ewma` : facteur de décroissance de l'EWMA ;
- `t0` : date de valorisation ;
- `stress_start`, `stress_end` : bornes de la période de stress historique ;
- `alpha` : niveau de confiance de l'Expected Shortfall ;
- `FHS_w`, `Stress_w` : poids de l'agrégation hybride ;
- `nominal` : nominal de référence des prix zéro-coupon.
"""
struct ModelConfig
    LP::Int
    HP::Int
    SW::Int
    lambda_ewma::Float64
    t0::Date
    stress_start::Date
    stress_end::Date
    alpha::Float64
    FHS_w::Float64
    Stress_w::Float64
    nominal::Float64
end

"""
    ModelConfig(; kwargs...)

Construit une configuration typée à partir de paramètres nommés. Les dates
peuvent être fournies comme `Date`, `DateTime` ou chaînes de caractères.
"""
function ModelConfig(; LP=2500, HP=5, SW=60, lambda_ewma=0.94,
    t0="2025-05-30", stress_start="2022-01-01", stress_end="2023-12-31",
    alpha=0.99, FHS_w=0.75, Stress_w=0.25, nominal=100.0)
    return ModelConfig(
        Int(LP),
        Int(HP),
        Int(SW),
        Float64(lambda_ewma),
        _as_date(t0),
        _as_date(stress_start),
        _as_date(stress_end),
        Float64(alpha),
        Float64(FHS_w),
        Float64(Stress_w),
        Float64(nominal),
    )
end
