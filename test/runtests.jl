using Dates
using Test
using DefaultFundJulia

# Cette suite utilise uniquement de petits jeux de données déterministes. Elle
# vérifie les contrats des fonctions sans dépendre du CSV ni du notebook.

@testset "Returns Litterman" begin
    # Sur le pilier 1Y : -1 × (3,1 % - 3,0 %) = -0,001.
    # Sur le pilier 2Y : -2 × (3,8 % - 4,0 %) =  0,004.
    curve = CurveMatrix(
        [Date(2024, 1, 1), Date(2024, 1, 2)],
        [1.0, 2.0],
        [
            0.030 0.040
            0.031 0.038
        ],
    )

    returns = compute_litterman_zero_returns(curve; HP=1)

    @test returns.dates == [Date(2024, 1, 2)]
    @test returns.pillars == [1.0, 2.0]
    @test isapprox(returns.values, [-0.001 0.004]; atol=1e-12)
    @test_throws ErrorException compute_litterman_zero_returns(curve; HP=0)
end

@testset "Expected Shortfall et marge initiale" begin
    pnl = [-10.0, 2.0, -5.0, 1.0]

    # Au niveau 75 % et avec quatre scénarios, seule la pire perte est retenue.
    @test compute_es_from_pnl(pnl; alpha=0.75) == 10.0
    # Une série entièrement gagnante ne doit jamais créer une marge négative.
    @test compute_es_from_pnl([1.0, 2.0, 3.0]; alpha=0.99) == 0.0
    # L'IM retient l'agrégation hybride lorsque celle-ci dépasse l'ES FHS,
    # sinon le plancher FHS reste contraignant.
    @test compute_initial_margin(100.0, 200.0) == 125.0
    @test compute_initial_margin(100.0, 50.0) == 100.0
end

@testset "Pertes et SLOIM" begin
    # Les lignes sont les scénarios et les colonnes les membres.
    pnl = [
        -10.0  4.0 -3.0
          2.0 -8.0  1.0
    ]
    expected_losses = [
        10.0 0.0 3.0
         0.0 8.0 0.0
    ]
    expected_sloim = [
        6.0 0.0 2.0
        0.0 3.0 0.0
    ]

    losses = losses_from_pnl(pnl)
    sloim = compute_sloim(losses, [4.0, 5.0, 1.0])

    @test losses == expected_losses
    @test sloim == expected_sloim
    # Une marge manquante rendrait ambiguë l'association membre-colonne.
    @test_throws ErrorException compute_sloim(losses, [4.0, 5.0])
end

@testset "Cover-2" begin
    # Scénario s1 : B + A = 20 + 10. Scénario s2 : C + B = 8 + 7.
    sloim = [
        10.0 20.0 5.0
         0.0  7.0 8.0
    ]
    result = compute_cover2_by_scenario(sloim, ["s1", "s2"], ["A", "B", "C"])

    @test result.cover2_requirement == [30.0, 15.0]
    @test result.first_member == ["B", "C"]
    @test result.second_member == ["A", "B"]
    # Cover-2 requiert au moins deux membres et des labels cohérents avec
    # les dimensions de la matrice SLOIM.
    @test_throws ErrorException compute_cover2_by_scenario(
        reshape([1.0, 2.0], 2, 1),
        ["s1", "s2"],
        ["A"],
    )
    @test_throws ErrorException compute_cover2_by_scenario(
        sloim,
        ["s1"],
        ["A", "B", "C"],
    )
end

@testset "Scenarios ACP par queues" begin
    # La matrice synthétique possède trois piliers et suffisamment de dates
    # pour ajuster trois composantes non triviales.
    dates = Date(2024, 1, 1) .+ Day.(0:7)
    returns = CurveMatrix(
        dates,
        [1.0, 5.0, 10.0],
        [
             0.01  0.00 -0.01
             0.02  0.01  0.00
            -0.01  0.02  0.01
             0.00 -0.01  0.02
             0.03  0.00  0.01
            -0.02 -0.01  0.00
             0.01  0.03 -0.02
            -0.03  0.01  0.03
        ],
    )

    model = fit_pca_stress(returns; n_components=3)
    scenarios = build_tail_hypothetical_scenarios(model; alpha=0.75)

    # Deux queues par composante doivent produire exactement six scénarios.
    @test issorted(model.eigenvalues; rev=true)
    @test size(model.scores) == (8, 3)
    @test length(scenarios.labels) == 6
    @test size(scenarios.values) == (6, 3)
    @test all(isfinite, scenarios.values)
end

@testset "Concatenation des scenarios" begin
    # Les deux familles partagent la même grille de piliers et peuvent être
    # empilées sans modifier l'ordre de leurs lignes.
    historical = ScenarioMatrix(["H1"], [1.0, 5.0], [0.01 -0.02])
    hypothetical = ScenarioMatrix(
        ["P1", "P2"],
        [1.0, 5.0],
        [
             0.03 0.04
            -0.01 0.02
        ],
    )

    combined = concat_scenarios(historical, hypothetical)

    @test combined.labels == ["H1", "P1", "P2"]
    @test size(combined.values) == (3, 2)
    @test combined.values[1, :] == [0.01, -0.02]
    # Une grille différente rendrait les colonnes incomparables.
    @test_throws ErrorException concat_scenarios(
        historical,
        ScenarioMatrix(["bad"], [2.0, 10.0], [0.0 0.0]),
    )
end
