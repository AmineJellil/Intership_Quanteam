using Dates

struct CurveMatrix
    dates::Vector{Date}
    pillars::Vector{Float64}
    values::Matrix{Float64}
end

struct ScenarioMatrix
    labels::Vector{String}
    pillars::Vector{Float64}
    values::Matrix{Float64}
end

function _check_matrix_shape(row_count::Int, col_count::Int, values::Matrix{Float64})
    size(values, 1) == row_count || error("Nombre de lignes incoherent.")
    size(values, 2) == col_count || error("Nombre de colonnes incoherent.")
    return nothing
end

function CurveMatrix(dates::Vector{Date}, pillars::Vector{Float64}, values::AbstractMatrix)
    vals = Matrix{Float64}(values)
    _check_matrix_shape(length(dates), length(pillars), vals)
    return CurveMatrix(dates, pillars, vals)
end

function ScenarioMatrix(labels::Vector{String}, pillars::Vector{Float64}, values::AbstractMatrix)
    vals = Matrix{Float64}(values)
    _check_matrix_shape(length(labels), length(pillars), vals)
    return ScenarioMatrix(labels, pillars, vals)
end

function as_scenarios(curve::CurveMatrix; prefix::String="")
    labels = isempty(prefix) ? string.(curve.dates) : [prefix * string(d) for d in curve.dates]
    return ScenarioMatrix(labels, curve.pillars, curve.values)
end

function concat_scenarios(scenarios::ScenarioMatrix...)
    isempty(scenarios) && error("Aucun scenario a concatener.")
    pillars = scenarios[1].pillars
    for s in scenarios
        s.pillars == pillars || error("Les piliers des scenarios ne coincident pas.")
    end
    labels = reduce(vcat, [s.labels for s in scenarios])
    values = reduce(vcat, [s.values for s in scenarios])
    return ScenarioMatrix(labels, pillars, values)
end
