using CSV
using DataFrames
using Dates

function _parse_curve_date(x)
    x isa Date && return x
    x isa DateTime && return Date(x)
    s = String(x)
    try
        return Date(s)
    catch
        return Date(DateTime(s, dateformat"yyyy-mm-dd HH:MM:SS"))
    end
end

function load_zero_coupon_curve(path)::CurveMatrix
    df = DataFrame(CSV.File(path))
    date_col = names(df)[1]
    value_cols = names(df)[2:end]

    dates = [_parse_curve_date(x) for x in df[!, date_col]]
    pillars = [parse(Float64, String(c)) for c in value_cols]
    values = Matrix{Float64}(df[:, value_cols])

    return clean_zero_coupon_curve(CurveMatrix(dates, pillars, values))
end

function clean_zero_coupon_curve(curve::CurveMatrix)::CurveMatrix
    seen = Set{Date}()
    keep = Int[]
    for (i, d) in enumerate(curve.dates)
        if !(d in seen) && all(isfinite, curve.values[i, :])
            push!(keep, i)
            push!(seen, d)
        end
    end

    sorted_keep = sort(keep, by=i -> curve.dates[i])
    return CurveMatrix(curve.dates[sorted_keep], curve.pillars, curve.values[sorted_keep, :])
end

function row_at(curve::CurveMatrix, date)::Vector{Float64}
    target = _as_date(date)
    idx = findfirst(==(target), curve.dates)
    idx === nothing && error("Date absente de la courbe: $(target)")
    return vec(curve.values[idx, :])
end
