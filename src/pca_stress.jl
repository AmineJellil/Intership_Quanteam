using DataFrames
using LinearAlgebra
using Statistics

struct PCAStressModel
    pillars::Vector{Float64}
    mean::Vector{Float64}
    eigenvalues::Vector{Float64}
    loadings::Matrix{Float64}
    scores::Matrix{Float64}
    dates::Vector{Date}
end

function fit_pca_stress(returns::CurveMatrix; n_components::Int=3)
    X = returns.values
    mu = vec(mean(X; dims=1))
    Xc = X .- reshape(mu, 1, :)
    cov_matrix = Symmetric((Xc' * Xc) / (size(Xc, 1) - 1))
    eig = eigen(cov_matrix)
    order = sortperm(eig.values; rev=true)
    selected = order[1:n_components]
    eigenvalues = eig.values[selected]
    loadings = eig.vectors[:, selected]
    scores = Xc * loadings
    return PCAStressModel(returns.pillars, mu, eigenvalues, loadings, scores, returns.dates)
end

function standardized_scores(model::PCAStressModel)
    sigma = reshape(sqrt.(model.eigenvalues), 1, :)
    return model.scores ./ sigma
end

function _reconstruct_from_multipliers(model::PCAStressModel, multipliers::Vector{Float64})
    length(multipliers) == length(model.eigenvalues) ||
        error("Nombre de multiplicateurs incompatible avec le modele ACP.")
    scores = multipliers .* sqrt.(model.eigenvalues)
    return vec(model.loadings * scores)
end

function build_quantile_hypothetical_scenarios(
    model::PCAStressModel;
    quantile_level::Float64=0.995,
)
    U = standardized_scores(model)
    rows = Vector{Vector{Float64}}()
    labels = String[]
    k = length(model.eigenvalues)

    for component in 1:k
        high = quantile(U[:, component], quantile_level)
        low = quantile(U[:, component], 1.0 - quantile_level)

        m_high = zeros(Float64, k)
        m_low = zeros(Float64, k)
        m_high[component] = high
        m_low[component] = low

        push!(rows, _reconstruct_from_multipliers(model, m_high))
        push!(labels, "ACP_PC$(component)_Q$(round(quantile_level * 100; digits=2))")

        push!(rows, _reconstruct_from_multipliers(model, m_low))
        push!(labels, "ACP_PC$(component)_Q$(round((1.0 - quantile_level) * 100; digits=2))")
    end

    values = reduce(vcat, [reshape(r, 1, :) for r in rows])
    return ScenarioMatrix(labels, model.pillars, values)
end

function build_grid_hypothetical_scenarios(
    model::PCAStressModel;
    quantile_levels::Vector{Float64}=[0.005, 0.025, 0.05, 0.25, 0.75, 0.95, 0.975, 0.995],
    prefix::String="ACP_GRID",
)
    U = standardized_scores(model)
    k = length(model.eigenvalues)
    length(quantile_levels) >= 2 ||
        error("La grille ACP nécessite au moins deux niveaux de quantile.")

    multipliers_by_component = [
        [quantile(U[:, component], q) for q in quantile_levels]
        for component in 1:k
    ]

    rows = Vector{Vector{Float64}}()
    labels = String[]
    index_ranges = ntuple(_ -> eachindex(quantile_levels), k)

    for idxs in Iterators.product(index_ranges...)
        multipliers = Float64[
            multipliers_by_component[component][idxs[component]]
            for component in 1:k
        ]

        label_parts = [
            "PC$(component)_Q$(round(quantile_levels[idxs[component]] * 100; digits=2))"
            for component in 1:k
        ]

        push!(rows, _reconstruct_from_multipliers(model, multipliers))
        push!(labels, "$(prefix)_" * join(label_parts, "_"))
    end

    values = reduce(vcat, [reshape(r, 1, :) for r in rows])
    return ScenarioMatrix(labels, model.pillars, values)
end

function compute_pc_tail_quantiles(model::PCAStressModel; alpha::Float64=0.99)
    0.0 < alpha < 1.0 || error("alpha doit etre strictement compris entre 0 et 1.")

    T_obs = size(model.scores, 1)
    n_obs = max(1, Int(round((1.0 - alpha) * T_obs)))
    rows = NamedTuple[]

    for component in 1:length(model.eigenvalues)
        sorted_scores = sort(model.scores[:, component])
        pc_down = mean(sorted_scores[1:n_obs])
        pc_up = mean(sorted_scores[(end - n_obs + 1):end])

        push!(rows, (
            component=component,
            component_name="PC$(component)",
            side="down",
            alpha=alpha,
            n_obs=n_obs,
            pc_tail_mean=pc_down,
        ))

        push!(rows, (
            component=component,
            component_name="PC$(component)",
            side="up",
            alpha=alpha,
            n_obs=n_obs,
            pc_tail_mean=pc_up,
        ))
    end

    return DataFrame(rows)
end

function build_tail_hypothetical_scenarios(model::PCAStressModel; alpha::Float64=0.99)
    tail_quantiles = compute_pc_tail_quantiles(model; alpha=alpha)

    movement_names = Dict(
        1 => "P_MOV",
        2 => "S_MOV",
        3 => "C_MOV",
    )

    labels = String[]
    rows = Vector{Vector{Float64}}()

    for row in eachrow(tail_quantiles)
        component = row.component
        movement = get(movement_names, component, "PC$(component)_MOV")
        side = uppercase(row.side)

        push!(labels, "ACP_HYPO_$(movement)_$(side)_alpha$(Int(round(row.alpha * 100)))")
        push!(rows, vec(model.loadings[:, component] .* row.pc_tail_mean))
    end

    values = reduce(vcat, [reshape(row, 1, :) for row in rows])
    return ScenarioMatrix(labels, model.pillars, values)
end

