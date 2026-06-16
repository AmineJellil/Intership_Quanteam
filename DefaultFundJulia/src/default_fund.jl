using DataFrames

function losses_from_pnl(pnl::AbstractMatrix)
    return max.(-pnl, 0.0)
end

function compute_sloim(stress_losses::AbstractMatrix, initial_margin::AbstractVector)
    im = reshape(collect(initial_margin), 1, :)
    return max.(stress_losses .- im, 0.0)
end

function compute_cover2_by_scenario(
    sloim::AbstractMatrix,
    scenario_labels::Vector{String},
    member_names::Vector{String},
)
    size(sloim, 2) >= 2 || error("Le calcul Cover-2 necessite au moins deux membres.")
    rows = NamedTuple[]
    for i in axes(sloim, 1)
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

function allocate_default_fund(total_fund::Real, risk_basis;
    minimum_share::Float64=0.0)
    basis = max.(Float64.(collect(risk_basis)), 0.0)
    isempty(basis) && error("La base d'allocation est vide.")
    sum(basis) > 0 || error("La base d'allocation doit etre positive.")
    minimum_share * length(basis) < 1.0 ||
        error("La somme des minima depasse le fonds disponible.")

    total = Float64(total_fund)
    minimum_amount = total * minimum_share
    residual_pool = total - minimum_amount * length(basis)
    weights = basis ./ sum(basis)
    contributions = minimum_amount .+ residual_pool .* weights

    return DataFrame(
        risk_basis=basis,
        risk_weight=weights,
        minimum_contribution=fill(minimum_amount, length(basis)),
        risk_based_contribution=residual_pool .* weights,
        total_contribution=contributions,
        final_share=contributions ./ total,
    )
end
