# DefaultFundJulia

Prototype Julia pour prolonger le moteur Python existant vers le fonds de
defaut Cover-2 et les scenarios de stress hybrides.

Le code Python du dossier `IM_pipeline./IM_pipeline` reste la reference. Ce
projet Julia sert a developper progressivement une implementation autonome,
avec une validation croisee contre les resultats Python.

## Objectif

Le pipeline cible est :

1. charger et nettoyer la courbe zero-coupon ;
2. construire les prix ZC et les returns historiques ;
3. construire les scenarios FHS et stress historiques ;
4. ajouter des scenarios hypothetiques par ACP ;
5. calculer les PnL par membre ;
6. calculer IM, SLOIM, Cover-2 et allocation du fonds.

Les scenarios ACP sont ajoutes au jeu de stress :

```julia
stress_scenarios = concat_scenarios(historical_stress, acp_hypothetical)
```

Puis ce jeu commun est utilise pour les PnL stress, les SLOIM et le Cover-2.

## Lancer le prototype

Depuis la racine du depot :

```bash
julia --project=DefaultFundJulia DefaultFundJulia/examples/run_default_fund_pipeline.jl
```

Puis installer les dependances si necessaire :

```julia
] instantiate
```

## Structure

```text
DefaultFundJulia/
  Project.toml
  README.md
  src/
    DefaultFundJulia.jl
    config.jl
    data_types.jl
    market_data.jl
    risk_factors.jl
    scenarios.jl
    pricing.jl
    risk_measures.jl
    pca_stress.jl
    default_fund.jl
  examples/
    run_default_fund_pipeline.jl
  test/
    runtests.jl
```

## Notes

- `ACP` signifie ici analyse en composantes principales.
- `apc.py` dans le projet Python correspond a l'anti-procyclicite ; c'est un
  autre sujet.
- Le module ACP genere des scenarios hypothetiques. Il ne remplace pas les
  scenarios historiques.
