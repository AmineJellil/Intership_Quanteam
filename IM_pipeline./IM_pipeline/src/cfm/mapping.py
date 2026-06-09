"""Mapping des cash-flows sur les piliers adjacents de la courbe ZC."""

from __future__ import annotations

import math

import numpy as np
import pandas as pd

from src.pricing.discounting import get_discount_factor_from_zc_price_curve


def _as_float_columns(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out.columns = [float(col) for col in out.columns]
    return out


def find_adjacent_pillars(
    pillars: list[float] | np.ndarray | pd.Index,
    maturity: float,
) -> tuple[float, float, float]:
    """Renvoie le pilier bas, le pilier haut et alpha pour l'interpolation."""
    grid = np.asarray(pillars, dtype=float)
    grid = np.sort(grid)
    maturity = float(maturity)

    if maturity <= grid[0]:
        return float(grid[0]), float(grid[0]), 0.0
    if maturity >= grid[-1]:
        return float(grid[-1]), float(grid[-1]), 0.0

    upper_idx = int(np.searchsorted(grid, maturity, side="left"))
    upper = float(grid[upper_idx])
    lower = float(grid[upper_idx - 1])

    if math.isclose(maturity, upper, rel_tol=0.0, abs_tol=1e-12):
        return upper, upper, 0.0

    alpha = (maturity - lower) / (upper - lower)
    return lower, upper, float(alpha)


def temporal_cfm_weights(alpha: float) -> tuple[float, float]:
    """Poids CFM temporels : pilier bas = 1-alpha, pilier haut = alpha."""
    alpha = float(alpha)
    return 1.0 - alpha, alpha


def variance_matching_lower_weight(
    alpha: float,
    lower_pillar: float,
    upper_pillar: float,
    returns_window: pd.DataFrame,
) -> tuple[float, str]:
    """Calcule le poids CFM du pilier bas par préservation de variance.

    La volatilité cible intermédiaire est approximée par une combinaison
    temporelle des volatilités des deux piliers. Si l'équation quadratique
    ne fournit pas de racine admissible stable, la fonction revient aux
    poids temporels.
    """
    if math.isclose(lower_pillar, upper_pillar, rel_tol=0.0, abs_tol=1e-12):
        return 1.0, "exact_pillar"

    returns_window = _as_float_columns(returns_window)
    if lower_pillar not in returns_window.columns or upper_pillar not in returns_window.columns:
        return 1.0 - alpha, "fallback_missing_pillar"

    pair = returns_window[[lower_pillar, upper_pillar]].dropna()
    if len(pair) < 2:
        return 1.0 - alpha, "fallback_insufficient_history"

    sigma_lower = float(pair[lower_pillar].std(ddof=1))
    sigma_upper = float(pair[upper_pillar].std(ddof=1))
    rho = float(pair[lower_pillar].corr(pair[upper_pillar]))

    if not np.isfinite([sigma_lower, sigma_upper, rho]).all():
        return 1.0 - alpha, "fallback_non_finite_stats"
    if sigma_lower <= 0.0 or sigma_upper <= 0.0:
        return 1.0 - alpha, "fallback_zero_volatility"

    phi_lower, phi_upper = temporal_cfm_weights(alpha)
    sigma_target = phi_lower * sigma_lower + phi_upper * sigma_upper

    a = sigma_lower**2 + sigma_upper**2 - 2.0 * sigma_lower * sigma_upper * rho
    b = 2.0 * (sigma_lower * sigma_upper * rho - sigma_upper**2)
    c = sigma_upper**2 - sigma_target**2

    candidates: list[float] = []
    if abs(a) < 1e-18:
        if abs(b) > 1e-18:
            candidates.append(-c / b)
    else:
        discriminant = b**2 - 4.0 * a * c
        if discriminant >= -1e-18:
            discriminant = max(discriminant, 0.0)
            root = math.sqrt(discriminant)
            candidates.extend([(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)])

    valid = [w for w in candidates if np.isfinite(w) and -1e-12 <= w <= 1.0 + 1e-12]
    if not valid:
        return phi_lower, "fallback_no_admissible_root"

    weight = min(valid, key=lambda w: abs(w - phi_lower))
    return float(min(1.0, max(0.0, weight))), "variance_matching"


def map_cashflows_to_pillars(
    cashflows: pd.DataFrame,
    current_zc_price_curve: pd.Series,
    returns_for_weights: pd.DataFrame | None = None,
    method: str = "variance",
    zc_nominal: float = 100.0,
) -> pd.DataFrame:
    """Mappe chaque valeur de marché de cash-flow sur les piliers ZC voisins.

    Parameters
    ----------
    cashflows : pd.DataFrame
        Sortie de ``build_portfolio_cashflows``.
    current_zc_price_curve : pd.Series
        Courbe courante de prix ZC, indexée par piliers.
    returns_for_weights : pd.DataFrame | None
        Returns historiques utilisés pour estimer les poids variance/corrélation.
    method : {"variance", "temporal"}
        Schéma de mapping. ``variance`` revient à temporel si nécessaire.
    zc_nominal : float
        Nominal des prix ZC.
    """
    if method not in {"variance", "temporal"}:
        raise ValueError("method doit valoir 'variance' ou 'temporal'")

    pillars = current_zc_price_curve.index.astype(float)
    rows = []

    for row in cashflows.itertuples(index=False):
        maturity = float(row.maturity)
        cashflow = float(row.cashflow)
        lower, upper, alpha = find_adjacent_pillars(pillars, maturity)
        market_value = cashflow * get_discount_factor_from_zc_price_curve(
            current_zc_price_curve,
            maturity=maturity,
            zc_nominal=zc_nominal,
        )

        if method == "variance" and returns_for_weights is not None:
            lower_weight, status = variance_matching_lower_weight(
                alpha, lower, upper, returns_for_weights
            )
            upper_weight = 1.0 - lower_weight
        else:
            lower_weight, upper_weight = temporal_cfm_weights(alpha)
            status = "temporal"

        legs = [(lower, lower_weight)]
        if not math.isclose(lower, upper, rel_tol=0.0, abs_tol=1e-12):
            legs.append((upper, upper_weight))

        for pillar, weight in legs:
            rows.append(
                {
                    "position_id": row.position_id,
                    "instrument": row.instrument,
                    "cashflow_maturity": maturity,
                    "cashflow": cashflow,
                    "cashflow_market_value": market_value,
                    "pillar": float(pillar),
                    "weight": float(weight),
                    "mapped_value": market_value * float(weight),
                    "mapping_status": status,
                }
            )

    return pd.DataFrame(rows)


def aggregate_mapped_exposures(
    mapped_cashflows: pd.DataFrame,
    pillars: pd.Index | list[float] | None = None,
) -> pd.Series:
    """Agrège les valeurs de marché mappées par pilier de courbe."""
    exposures = mapped_cashflows.groupby("pillar")["mapped_value"].sum().sort_index()
    if pillars is not None:
        exposures = exposures.reindex([float(p) for p in pillars], fill_value=0.0)
    return exposures
