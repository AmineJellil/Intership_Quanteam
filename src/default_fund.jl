using DataFrames

"""
    losses_from_pnl(pnl)

Convertit une matrice de PnL en pertes positives selon
`L(s, i) = max(-PnL(s, i), 0)`. Les lignes représentent les scénarios et les
colonnes les membres compensateurs.
"""
function losses_from_pnl(pnl::AbstractMatrix)
    return max.(-pnl, 0.0)
end

"""
    compute_sloim(stress_losses, initial_margin)

Calcule la perte stressée résiduelle au-delà de la marge initiale :
`SLOIM(s, i) = max(L(s, i) - IM(i), 0)`.

`initial_margin` doit contenir une valeur par colonne de `stress_losses`.
"""
function compute_sloim(stress_losses::AbstractMatrix, initial_margin::AbstractVector)
    size(stress_losses, 2) == length(initial_margin) ||
        error("Le nombre de marges initiales doit correspondre au nombre de membres.")
    im = reshape(collect(initial_margin), 1, :)
    return max.(stress_losses .- im, 0.0)
end

"""
    compute_cover2_by_scenario(sloim, scenario_labels, member_names)

Classe les SLOIM de chaque scénario, sélectionne les deux plus grandes et les
additionne. Le `DataFrame` retourné conserve le scénario, les deux membres
contraignants et le besoin Cover-2 associé.

Le montant global du fonds est obtenu ensuite en prenant le maximum de la
colonne `cover2_requirement`.
"""
function compute_cover2_by_scenario(
    sloim::AbstractMatrix,
    scenario_labels::Vector{String},
    member_names::Vector{String},
)
    size(sloim, 2) >= 2 || error("Le calcul Cover-2 necessite au moins deux membres.")
    size(sloim, 1) == length(scenario_labels) ||
        error("Le nombre de scenarios ne correspond pas au nombre de lignes SLOIM.")
    size(sloim, 2) == length(member_names) ||
        error("Le nombre de membres ne correspond pas au nombre de colonnes SLOIM.")
    rows = NamedTuple[]
    for i in axes(sloim, 1)
        # Le classement est refait sous chaque scénario : les deux membres
        # doivent être simultanément exposés au même choc.
        ranking = sortperm(vec(sloim[i, :]); rev=true)
        first = ranking[1]
        second = ranking[2]
        first_sloim = Float64(sloim[i, first])
        second_sloim = Float64(sloim[i, second])
        push!(rows, (
            scenario=scenario_labels[i],
            first_member=member_names[first],
            first_sloim=first_sloim,
            second_member=member_names[second],
            second_sloim=second_sloim,
            cover2_requirement=first_sloim + second_sloim,
        ))
    end
    return DataFrame(rows)
end
