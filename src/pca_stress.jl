using DataFrames
using LinearAlgebra
using Statistics

"""
    PCAStressModel

Résultat compact de l'ACP ajustée sur une `CurveMatrix` de returns.

- `pillars` : maturités des `P` facteurs de risque d'origine ;
- `mean` : moyenne historique de chaque pilier, de longueur `P` ;
- `eigenvalues` : variances des `K` composantes retenues ;
- `loadings` : matrice `P × K` des vecteurs propres ;
- `scores` : coordonnées des `T` dates dans l'espace factoriel, dimension `T × K` ;
- `dates` : dates associées aux lignes de `scores`.
"""
struct PCAStressModel
    pillars::Vector{Float64}
    mean::Vector{Float64}
    eigenvalues::Vector{Float64}
    loadings::Matrix{Float64}
    scores::Matrix{Float64}
    dates::Vector{Date}
end

"""
    fit_pca_stress(returns; n_components=3) -> PCAStressModel

Centre les returns, estime leur covariance empirique avec le diviseur `T-1`,
puis conserve les `n_components` valeurs propres les plus élevées et leurs
vecteurs propres.

Les scores sont les projections datées `X_c × V`. Ils indiquent l'intensité et
le signe de chaque mouvement factoriel à chaque date historique.
"""
function fit_pca_stress(returns::CurveMatrix; n_components::Int=3)
    X = returns.values
    mu = vec(mean(X; dims=1))
    Xc = X .- reshape(mu, 1, :)

    # `Symmetric` informe l'algorithme spectral de la structure de covariance
    # et évite que de faibles erreurs numériques créent des valeurs complexes.
    cov_matrix = Symmetric((Xc' * Xc) / (size(Xc, 1) - 1))
    eig = eigen(cov_matrix)

    # `eigen` ne garantit pas ici l'ordre économique souhaité : on reclasse
    # explicitement les facteurs de la variance expliquée la plus forte à la plus faible.
    order = sortperm(eig.values; rev=true)
    selected = order[1:n_components]
    eigenvalues = eig.values[selected]
    loadings = eig.vectors[:, selected]
    scores = Xc * loadings
    return PCAStressModel(returns.pillars, mu, eigenvalues, loadings, scores, returns.dates)
end

"""
    standardized_scores(model)

Divise chaque score factoriel par l'écart-type de sa composante
`sqrt(eigenvalue)`. Les colonnes obtenues sont exprimées en nombres d'écarts-types
et deviennent comparables malgré des variances différentes.
"""
function standardized_scores(model::PCAStressModel)
    sigma = reshape(sqrt.(model.eigenvalues), 1, :)
    return model.scores ./ sigma
end

# Reconstruit un vecteur de choc dans l'espace des piliers à partir de
# multiplicateurs standardisés. Pour chaque facteur k : score_k = m_k × sqrt(lambda_k).
function _reconstruct_from_multipliers(model::PCAStressModel, multipliers::Vector{Float64})
    length(multipliers) == length(model.eigenvalues) ||
        error("Nombre de multiplicateurs incompatible avec le modele ACP.")
    scores = multipliers .* sqrt.(model.eigenvalues)
    return vec(model.loadings * scores)
end

"""
    build_quantile_hypothetical_scenarios(model; quantile_level=0.995)

Construit deux scénarios univariés par composante : un quantile haut et son
quantile bas symétrique dans les scores standardisés. Les autres composantes
sont fixées à zéro avant reconstruction sur les piliers.

Avec `K` composantes, la matrice retournée contient `2K` scénarios.
"""
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

        # Un seul facteur est activé à la fois afin d'isoler sa forme de choc.
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

"""
    build_grid_hypothetical_scenarios(model; quantile_levels=[...], prefix="ACP_GRID")

Construit la grille cartésienne de toutes les combinaisons de quantiles des
composantes. Si `Q` niveaux sont fournis pour `K` facteurs, `Q^K` scénarios
multifactoriels sont générés.
"""
function build_grid_hypothetical_scenarios(
    model::PCAStressModel;
    quantile_levels::Vector{Float64}=[0.005, 0.025, 0.05, 0.25, 0.75, 0.95, 0.975, 0.995],
    prefix::String="ACP_GRID",
)
    U = standardized_scores(model)
    k = length(model.eigenvalues)
    length(quantile_levels) >= 2 ||
        error("La grille ACP nécessite au moins deux niveaux de quantile.")

    # Chaque composante possède sa propre distribution empirique de scores.
    multipliers_by_component = [
        [quantile(U[:, component], q) for q in quantile_levels]
        for component in 1:k
    ]

    rows = Vector{Vector{Float64}}()
    labels = String[]
    index_ranges = ntuple(_ -> eachindex(quantile_levels), k)

    # `Iterators.product` énumère toutes les combinaisons de niveaux sans
    # imbriquer manuellement un nombre variable de boucles.
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

"""
    compute_pc_tail_quantiles(model; alpha=0.99) -> DataFrame

Pour chaque composante, calcule la moyenne des scores de la queue basse et de
la queue haute de probabilité `1-alpha`. Le tableau contient donc deux lignes
par composante avec le nombre d'observations retenues et le score moyen.
"""
function compute_pc_tail_quantiles(model::PCAStressModel; alpha::Float64=0.99)
    0.0 < alpha < 1.0 || error("alpha doit etre strictement compris entre 0 et 1.")

    T_obs = size(model.scores, 1)
    # Au moins une date est retenue, même lorsque l'échantillon est court.
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

"""
    build_tail_hypothetical_scenarios(model; alpha=0.99)

Projette les moyennes de queues calculées par `compute_pc_tail_quantiles` sur
les piliers de la courbe. Chaque scénario active une seule composante :
`Delta r_i = loading_i × score_moyen_queue_i`.

Les noms `P_MOV`, `S_MOV` et `C_MOV` servent uniquement de libellés usuels pour
les trois premiers facteurs ; leur interprétation doit rester confirmée par la
forme effective des loadings.
"""
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
        # Le score de queue est un scalaire ; le loading diffuse ce mouvement
        # sur l'ensemble des maturités de la courbe.
        push!(rows, vec(model.loadings[:, component] .* row.pc_tail_mean))
    end

    values = reduce(vcat, [reshape(row, 1, :) for row in rows])
    return ScenarioMatrix(labels, model.pillars, values)
end
