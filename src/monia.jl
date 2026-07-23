using CSV
using DataFrames
using Dates
using Statistics

"""
    MoniaSeries

Série temporelle de taux MONIA, avec une observation de taux décimal par date.
Ce type appartient à une extension exploratoire et n'est pas utilisé par le
notebook Cover-2 principal.
"""
struct MoniaSeries
    dates::Vector{Date}
    rates::Vector{Float64}
end

# Convertit les dates ISO du fichier MONIA vers le type `Date` de Julia.
function _parse_iso_date(x)
    x isa Date && return x
    return Date(string(x), dateformat"yyyy-mm-dd")
end

"""
    load_monia(path) -> MoniaSeries

Charge les colonnes `date_reference` et `monia_decimal`, contrôle leur
présence, puis trie la série par date croissante.
"""
function load_monia(path::AbstractString)
    df = CSV.read(path, DataFrame)
    required = [:date_reference, :monia_decimal]
    for col in required
        col in propertynames(df) || error("Colonne manquante dans le fichier MONIA: $(col)")
    end

    dates = [_parse_iso_date(x) for x in df.date_reference]
    rates = Float64.(df.monia_decimal)
    order = sortperm(dates)
    return MoniaSeries(dates[order], rates[order])
end

"""
    monia_common_indices(returns, monia)

Retourne les indices des returns ZC dont la date est aussi disponible dans la
série MONIA.
"""
function monia_common_indices(returns::CurveMatrix, monia::MoniaSeries)
    monia_dates = Set(monia.dates)
    return findall(d -> d in monia_dates, returns.dates)
end

"""
    build_monia_aligned_returns(returns, monia) -> CurveMatrix

Restreint la matrice de returns aux seules dates communes avec MONIA, sans
modifier les valeurs des returns.
"""
function build_monia_aligned_returns(returns::CurveMatrix, monia::MoniaSeries)
    selected = monia_common_indices(returns, monia)
    isempty(selected) && error("Aucune date commune entre les returns ZC et MONIA.")
    return CurveMatrix(returns.dates[selected], returns.pillars, returns.values[selected, :])
end

"""
    build_monia_excess_returns(returns, monia; HP, day_count=360.0)

Soustrait à chaque return ZC le rendement sans risque approximé sur l'horizon
`HP` : `r_MONIA × HP / day_count`. Le même rendement journalier est retranché
à tous les piliers d'une date donnée.
"""
function build_monia_excess_returns(
    returns::CurveMatrix,
    monia::MoniaSeries;
    HP::Int,
    day_count::Float64=360.0,
)
    HP > 0 || error("HP doit etre strictement positif.")
    selected = monia_common_indices(returns, monia)
    isempty(selected) && error("Aucune date commune entre les returns ZC et MONIA.")

    # Le dictionnaire permet d'aligner les taux sans supposer que les deux
    # séries possèdent le même calendrier ou le même nombre d'observations.
    monia_by_date = Dict(d => r for (d, r) in zip(monia.dates, monia.rates))
    selected_dates = returns.dates[selected]
    risk_free_returns = [monia_by_date[d] * HP / day_count for d in selected_dates]
    values = returns.values[selected, :] .- reshape(risk_free_returns, :, 1)

    return CurveMatrix(selected_dates, returns.pillars, values)
end

"""
    monia_summary(monia) -> DataFrame

Produit un résumé lisible de la période couverte et du taux MONIA moyen.
"""
function monia_summary(monia::MoniaSeries)
    return DataFrame(
        indicateur=["premiere date", "derniere date", "nombre observations", "taux moyen"],
        valeur=[
            string(first(monia.dates)),
            string(last(monia.dates)),
            string(length(monia.dates)),
            string(round(mean(monia.rates) * 100; digits=4)) * " %",
        ],
    )
end
