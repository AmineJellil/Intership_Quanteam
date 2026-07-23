using Dates
using Test
using DefaultFundJulia

@testset "Returns Litterman" begin
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

    @test compute_es_from_pnl(pnl; alpha=0.75) == 10.0
    @test compute_es_from_pnl([1.0, 2.0, 3.0]; alpha=0.99) == 0.0
    @test compute_initial_margin(100.0, 200.0) == 125.0
    @test compute_initial_margin(100.0, 50.0) == 100.0
end

@testset "Pertes et SLOIM" begin
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
    @test_throws ErrorException compute_sloim(losses, [4.0, 5.0])
end

@testset "Cover-2" begin
    sloim = [
        10.0 20.0 5.0
         0.0  7.0 8.0
    ]
    result = compute_cover2_by_scenario(sloim, ["s1", "s2"], ["A", "B", "C"])

    @test result.cover2_requirement == [30.0, 15.0]
    @test result.first_member == ["B", "C"]
    @test result.second_member == ["A", "B"]
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

    @test issorted(model.eigenvalues; rev=true)
    @test size(model.scores) == (8, 3)
    @test length(scenarios.labels) == 6
    @test size(scenarios.values) == (6, 3)
    @test all(isfinite, scenarios.values)
end

@testset "Concatenation des scenarios" begin
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
    @test_throws ErrorException concat_scenarios(
        historical,
        ScenarioMatrix(["bad"], [2.0, 10.0], [0.0 0.0]),
    )
end
