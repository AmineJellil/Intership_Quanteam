using Test
using DefaultFundJulia

@testset "Expected shortfall" begin
    pnl = [-10.0, 2.0, -5.0, 1.0]
    @test compute_es_from_pnl(pnl; alpha=0.75) == 10.0
end

@testset "Cover-2" begin
    sloim = [
        10.0 20.0 5.0
        0.0 7.0 8.0
    ]
    df = compute_cover2_by_scenario(sloim, ["s1", "s2"], ["A", "B", "C"])
    @test df.cover2_requirement == [30.0, 15.0]
end

@testset "Allocation" begin
    df = allocate_default_fund(100.0, [1.0, 3.0]; minimum_share=0.1)
    @test isapprox(sum(df.total_contribution), 100.0)
    @test all(df.total_contribution .>= 10.0)
end
