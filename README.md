# DefaultFundJulia

Prototype Julia de calcul du risque de defaut d'une chambre de compensation
(CCP), depuis la construction des scenarios de stress jusqu'au dimensionnement
du fonds de defaut selon le standard Cover-2.

Le projet reprend progressivement en Julia la chaine de calcul initialement
etudiee en Python. Le notebook principal met aujourd'hui en oeuvre :

- le chargement et le nettoyage d'une courbe zero-coupon marocaine ;
- la construction de returns de taux adaptes a l'analyse factorielle ;
- une analyse en composantes principales (ACP) de la courbe ;
- des scenarios historiques et hypothetiques issus de l'ACP ;
- la revalorisation de portefeuilles obligataires sous chaque scenario ;
- le calcul de la marge initiale de chaque membre ;
- le calcul des pertes residuelles SLOIM ;
- le dimensionnement du fonds de defaut Cover-2.

## Objectif du projet

La marge initiale protege la CCP contre les pertes probables d'un membre sur
un horizon de liquidation. Le fonds de defaut intervient lorsque les pertes
stressees depassent cette marge.

Pour un membre `i` et un scenario `s`, la perte residuelle est :

```text
SLOIM_i(s) = max(Perte_i(s) - IM_i, 0)
```

Le besoin Cover-2 sous le scenario `s` est la somme des deux plus grandes
SLOIM simultanees :

```text
Cover2(s) = SLOIM_(1)(s) + SLOIM_(2)(s)
```

Le montant brut du fonds de defaut est alors :

```text
DF_Cover2 = max_s Cover2(s)
```

Le calcul conserve donc la dependance entre membres : les deux expositions
retenues doivent provenir du meme scenario de stress.

## Chaine de calcul implementee

### 1. Donnees de marche

Le fichier `ZeroCouponCurve.csv` contient :

- une ligne par date d'observation ;
- une premiere colonne de dates ;
- une colonne par maturite ou pilier de la courbe ZC ;
- des taux zero-coupon exprimes sous forme decimale.

Le chargeur trie les dates, retire les doublons et elimine les lignes qui
contiennent des valeurs non finies.

Le notebook recherche d'abord le fichier ici :

```text
data/raw/ZeroCouponCurve.csv
```

Il conserve aussi des chemins de repli vers les anciens depots Python locaux.
Pour rendre le depot autonome, le chemin recommande reste `data/raw/`.

### 2. Returns de taux pour l'ACP

L'ACP est ajustee sur des variations de taux transformees en approximation de
return d'un zero-coupon :

```text
R(t, T_k) = -T_k * (y(t, T_k) - y(t-HP, T_k))
```

ou :

- `T_k` est la maturite du pilier `k` ;
- `y(t, T_k)` est le taux ZC du pilier a la date `t` ;
- `HP` est l'horizon du mouvement historique, fixe a 5 observations dans le
  notebook.

Cette transformation mesure directement l'effet de premier ordre d'un
mouvement de taux sur un instrument ZC. Elle evite qu'un meme mouvement de taux
soit traite de la meme maniere a 3 mois et a 30 ans.

### 3. Analyse en composantes principales

Les returns sont centres, puis la matrice de covariance empirique est calculee :

```text
Sigma = Xc' * Xc / (N - 1)
```

Les valeurs propres sont classees par ordre decroissant. Les trois premiers
vecteurs propres sont conserves afin de representer les principaux mouvements
de la courbe :

- `PC1` : premier mouvement factoriel, generalement proche du niveau ;
- `PC2` : deuxieme mouvement, generalement proche de la pente ;
- `PC3` : troisieme mouvement, generalement proche de la courbure.

Cette interpretation est verifiee graphiquement a partir de la forme des
loadings. Elle n'est pas imposee dans le code : les composantes sont d'abord
classees selon la variance qu'elles expliquent.

Le modele ACP conserve :

- les maturites des piliers ;
- la moyenne historique de chaque pilier ;
- les trois valeurs propres ;
- les loadings ou vecteurs propres ;
- les scores de chaque date sur chaque composante ;
- les dates des observations.

### 4. Scenarios historiques ACP

Pour chaque composante `PC_i`, le notebook recherche les dates auxquelles son
score est minimal et maximal :

```text
date_i_minus = argmin_t PC_i(t)
date_i_plus  = argmax_t PC_i(t)
```

Le vecteur complet de returns observe a chacune de ces dates est ensuite
retenu comme scenario historique. Une date selectionnee par plusieurs
composantes n'est conservee qu'une seule fois.

Avec trois composantes, on obtient au maximum six scenarios historiques
distincts.

### 5. Scenarios hypothetiques ACP par queues

Pour chaque composante, les scores historiques sont tries. Avec
`alpha = 99 %`, le moteur calcule :

- la moyenne des scores situes dans la queue basse de 1 % ;
- la moyenne des scores situes dans la queue haute de 1 %.

Chaque moyenne de queue est projetee sur tous les piliers au moyen du loading
de la composante correspondante :

```text
Delta_r_PC_i_down = v_i * moyenne_queue_basse_i
Delta_r_PC_i_up   = v_i * moyenne_queue_haute_i
```

Le notebook construit donc six scenarios hypothetiques univaries :

- `PC1_DOWN` et `PC1_UP` ;
- `PC2_DOWN` et `PC2_UP` ;
- `PC3_DOWN` et `PC3_UP`.

Le module contient egalement des constructeurs par quantiles ponctuels et par
grille multifactorielle. Le notebook principal utilise actuellement la methode
par moyenne des queues.

### 6. Matrice commune de stress

Les scenarios historiques ACP et les scenarios hypothetiques sont regroupes
dans une seule `ScenarioMatrix` :

```text
scenarios_stress = scenarios_historiques_ACP + scenarios_hypothetiques_ACP
```

Les lignes representent les scenarios et les colonnes les piliers ZC. Cette
matrice est utilisee pour calculer les PnL stresses, les pertes, la SLOIM et le
Cover-2.

### 7. Portefeuilles et revalorisation

Le notebook definit quatre membres compensateurs. Chaque membre possede un
portefeuille d'obligations marocaines a taux fixe avec :

- un nom ;
- une maturite residuelle ;
- un taux de coupon ;
- un nominal ;
- une frequence de coupon ;
- une quantite positive ou negative.

La valeur initiale d'une obligation est la somme de ses cash-flows actualises
par interpolation de la courbe de prix ZC. Pour un scenario `s`, la courbe de
prix est choquee pilier par pilier :

```text
P_s(T_k) = P_0(T_k) * (1 + R_s(T_k))
```

Le portefeuille est ensuite completement revalorise :

```text
PnL_i(s) = V_i(s) - V_i(0)
```

Le moteur produit une matrice `scenario x membre`, ainsi qu'un resume des
meilleurs et des pires PnL par membre.

### 8. Marge initiale

La marge initiale est calculee separement du jeu de stress ACP. Elle reutilise
la methodologie historique du moteur d'IM :

1. returns relatifs des prix ZC sur l'horizon `HP` ;
2. volatilites conditionnelles EWMA ;
3. scenarios FHS recents scales vers la volatilite courante ;
4. scenarios de stress historiques non scales ;
5. Expected Shortfall empirique au niveau `alpha = 99 %`.

Pour chaque membre :

```text
ES_hybrid = w_FHS * ES_FHS + w_stress * ES_stress
IM        = max(ES_FHS, ES_hybrid)
```

Les poids par defaut sont `w_FHS = 75 %` et `w_stress = 25 %`. Le maximum
applique un plancher egal a l'ES FHS.

### 9. Pertes stressees et SLOIM

Le PnL de chaque membre est transforme en perte positive :

```text
Perte_i(s) = max(-PnL_i(s), 0)
```

La SLOIM correspond ensuite a la perte qui depasse la marge initiale :

```text
SLOIM_i(s) = max(Perte_i(s) - IM_i, 0)
```

Une SLOIM nulle signifie que la marge initiale absorbe entierement la perte du
membre sous le scenario considere.

### 10. Dimensionnement Cover-2

Sous chaque scenario, les SLOIM sont classees par ordre decroissant. Le moteur
enregistre :

- le premier membre ;
- sa SLOIM ;
- le deuxieme membre ;
- sa SLOIM ;
- leur somme, qui constitue le besoin Cover-2 du scenario.

Le scenario contraignant est celui qui produit la somme la plus elevee. Le
notebook affiche le montant final, la famille du scenario et les deux membres
qui determinent le besoin.

## Notebook principal

Le travail complet est documente dans :

```text
notebooks/run_appendix_pca_julia.ipynb
```

Le notebook contient les 22 sections suivantes :

1. preparation de l'environnement ;
2. parametres du calcul ;
3. chargement de la courbe ZC ;
4. calcul des returns de taux ;
5. statistiques descriptives ;
6. ajustement de l'ACP ;
7. loadings sur les piliers ;
8. scores factoriels dans le temps ;
9. extraction des dates historiques extremes ;
10. matrice des scenarios historiques ;
11. estimation des queues des scores ;
12. scenarios hypothetiques ;
13. recapitulatif de la matrice de stress ;
14. portefeuilles des membres ;
15. valeurs initiales ;
16. PnL stresses ;
17. resume des PnL ;
18. pertes stressees ;
19. marge initiale ;
20. SLOIM ;
21. Cover-2 ;
22. conclusion et interpretation du resultat Cover-2.

## Installation

### Prerequis

- Julia 1.10 ou version compatible ;
- un environnement Jupyter/IJulia pour ouvrir le notebook ;
- le fichier de courbe ZC.

Depuis la racine du depot :

```bash
julia --project=.
```

Puis, dans le REPL Julia :

```julia
using Pkg
Pkg.instantiate()
```

`Project.toml` declare les dependances directes. `Manifest.toml` verrouille
leurs versions exactes pour rendre l'environnement reproductible.

## Execution

### Depuis VS Code

1. ouvrir `notebooks/run_appendix_pca_julia.ipynb` ;
2. selectionner le kernel Julia ;
3. executer les cellules dans l'ordre.

La premiere cellule active automatiquement le projet et installe les
dependances absentes avec `Pkg.instantiate()`.

### Chargement du module

Le package peut aussi etre utilise directement :

```julia
using Pkg
Pkg.activate(".")
using DefaultFundJulia
```

## Tests

Les tests couvrent actuellement :

- les returns de taux utilises pour l'ACP ;
- l'Expected Shortfall et le plancher de marge initiale ;
- la conversion des PnL en pertes et le calcul de la SLOIM ;
- le classement des membres et la somme Cover-2 ;
- la construction des scenarios ACP par queues ;
- la concatenation des familles de scenarios.

Pour les executer :

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Structure du depot

```text
Stage_QuantFactory_Julia/
|-- .gitignore
|-- Project.toml
|-- Manifest.toml
|-- README.md
|-- data_monia/
|   |-- MONIA.csv
|   `-- MONIA_clean.csv
|-- notebooks/
|   `-- run_appendix_pca_julia.ipynb
|-- src/
|   |-- DefaultFundJulia.jl
|   |-- config.jl
|   |-- data_types.jl
|   |-- market_data.jl
|   |-- risk_factors.jl
|   |-- scenarios.jl
|   |-- pricing.jl
|   |-- risk_measures.jl
|   |-- pca_stress.jl
|   |-- default_fund.jl
|   `-- monia.jl
`-- test/
    `-- runtests.jl
```

### Responsabilite des modules

| Fichier              | Role                                                                |
| -------------------- | ------------------------------------------------------------------- |
| `data_types.jl`    | Structures matricielles de courbes et de scenarios                  |
| `config.jl`        | Parametres du modele et conversion des dates                        |
| `market_data.jl`   | Chargement et nettoyage des donnees ZC                              |
| `risk_factors.jl`  | Prix ZC et calcul des returns                                       |
| `scenarios.jl`     | EWMA, FHS et scenarios historiques generiques                       |
| `pca_stress.jl`    | ACP et scenarios hypothetiques par facteurs                         |
| `pricing.jl`       | Pricing obligataire et PnL sous scenarios                           |
| `risk_measures.jl` | Expected Shortfall et marge initiale                                |
| `default_fund.jl`  | Conversion des PnL en pertes, SLOIM et dimensionnement Cover-2       |
| `monia.jl`         | Module exploratoire conserve, non utilise par le notebook principal |

## Dependances principales

- `CSV.jl` pour la lecture des donnees ;
- `DataFrames.jl` pour les tableaux ;
- `LinearAlgebra` et `Statistics` pour l'ACP et les mesures statistiques ;
- `Plots.jl` pour les courbes de facteurs ;
- `IJulia.jl` pour le notebook Jupyter ;
- `Pluto.jl`, conserve pour les premiers essais de notebooks Julia ;
- `Test` pour les tests unitaires.

## Etat actuel et limites

Le prototype couvre la chaine de calcul jusqu'au Cover-2 sur des portefeuilles
obligataires synthetiques. Les principaux points encore experimentaux sont :

- les portefeuilles et quantites utilises dans le notebook ;
- l'interpretation economique des composantes, qui depend des donnees ;
- le choix de la periode historique et du niveau de queue ;
- les scenarios hypothetiques actuellement univaries ;
- l'extension a d'autres instruments et aux regles de netting reelles.
