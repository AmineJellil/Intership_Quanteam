using Dates

"""
    CurveMatrix

Matrice datée de courbe ou de facteurs de risque.

- une ligne de `values` correspond à une date ;
- une colonne correspond à un pilier de maturité ;
- `values` a donc la dimension `length(dates) × length(pillars)`.
"""
struct CurveMatrix
    dates::Vector{Date}
    pillars::Vector{Float64}
    values::Matrix{Float64}
end

"""
    ScenarioMatrix

Matrice de chocs utilisée pour la revalorisation.

- une ligne correspond à un scénario identifié par `labels` ;
- une colonne correspond à un pilier ZC ;
- chaque valeur est un return relatif appliqué au prix ZC du pilier.
"""
struct ScenarioMatrix
    labels::Vector{String}
    pillars::Vector{Float64}
    values::Matrix{Float64}
end

# Validation centralisée pour empêcher la création de conteneurs dont les axes
# descriptifs ne correspondent pas aux dimensions de la matrice numérique.
function _check_matrix_shape(row_count::Int, col_count::Int, values::Matrix{Float64})
    size(values, 1) == row_count || error("Nombre de lignes incoherent.")
    size(values, 2) == col_count || error("Nombre de colonnes incoherent.")
    return nothing
end

"""
    CurveMatrix(dates, pillars, values)

Convertit `values` en `Float64`, contrôle ses dimensions, puis construit une
`CurveMatrix` cohérente.
"""
function CurveMatrix(dates::Vector{Date}, pillars::Vector{Float64}, values::AbstractMatrix)
    vals = Matrix{Float64}(values)
    _check_matrix_shape(length(dates), length(pillars), vals)
    return CurveMatrix(dates, pillars, vals)
end

"""
    ScenarioMatrix(labels, pillars, values)

Convertit `values` en `Float64` et vérifie que le nombre de labels et de
piliers correspond aux dimensions de la matrice.
"""
function ScenarioMatrix(labels::Vector{String}, pillars::Vector{Float64}, values::AbstractMatrix)
    vals = Matrix{Float64}(values)
    _check_matrix_shape(length(labels), length(pillars), vals)
    return ScenarioMatrix(labels, pillars, vals)
end

"""
    as_scenarios(curve; prefix="")

Transforme chaque ligne datée d'une `CurveMatrix` en scénario. Le préfixe
optionnel facilite l'identification de la famille de scénarios.
"""
function as_scenarios(curve::CurveMatrix; prefix::String="")
    labels = isempty(prefix) ? string.(curve.dates) : [prefix * string(d) for d in curve.dates]
    return ScenarioMatrix(labels, curve.pillars, curve.values)
end

"""
    concat_scenarios(scenarios...)

Concatène verticalement plusieurs familles de scénarios. Tous les objets
doivent utiliser exactement les mêmes piliers et le même ordre de colonnes.
"""
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
