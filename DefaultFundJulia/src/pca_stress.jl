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
