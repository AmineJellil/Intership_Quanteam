using CSV
using DataFrames
using Dates
using Statistics

struct MoniaSeries
    dates::Vector{Date}
    rates::Vector{Float64}
end

function _parse_iso_date(x)
    x isa Date && return x
    return Date(string(x), dateformat"yyyy-mm-dd")
end

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

function monia_common_indices(returns::CurveMatrix, monia::MoniaSeries)
    monia_dates = Set(monia.dates)
    return findall(d -> d in monia_dates, returns.dates)
end

function build_monia_aligned_returns(returns::CurveMatrix, monia::MoniaSeries)
    selected = monia_common_indices(returns, monia)
    isempty(selected) && error("Aucune date commune entre les returns ZC et MONIA.")
    return CurveMatrix(returns.dates[selected], returns.pillars, returns.values[selected, :])
end

function build_monia_excess_returns(
    returns::CurveMatrix,
    monia::MoniaSeries;
    HP::Int,
    day_count::Float64=360.0,
)
    HP > 0 || error("HP doit etre strictement positif.")
    selected = monia_common_indices(returns, monia)
    isempty(selected) && error("Aucune date commune entre les returns ZC et MONIA.")

    monia_by_date = Dict(d => r for (d, r) in zip(monia.dates, monia.rates))
    selected_dates = returns.dates[selected]
    risk_free_returns = [monia_by_date[d] * HP / day_count for d in selected_dates]
    values = returns.values[selected, :] .- reshape(risk_free_returns, :, 1)

    return CurveMatrix(selected_dates, returns.pillars, values)
end

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
