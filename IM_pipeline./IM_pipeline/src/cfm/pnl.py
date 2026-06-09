"""Calcul du PnL selon l'approche Cash-Flow Mapping (CFM)."""

from __future__ import annotations

from typing import Any

import pandas as pd

from src.cfm.cashflows import build_portfolio_cashflows
from src.cfm.mapping import aggregate_mapped_exposures, map_cashflows_to_pillars


def compute_cfm_pnl_under_scenarios(
    mapped_exposures: pd.Series,
    scenario_returns_df: pd.DataFrame,
) -> pd.Series:
    """Calcule le PnL CFM sous scénarios depuis les expositions par pilier."""
    scenario_returns_df = scenario_returns_df.copy()
    scenario_returns_df.columns = [float(col) for col in scenario_returns_df.columns]
    exposures = mapped_exposures.reindex(scenario_returns_df.columns, fill_value=0.0)
    return scenario_returns_df.mul(exposures, axis=1).sum(axis=1)


def compute_portfolio_pnl_cfm(
    current_zc_price_curve: pd.Series,
    scenario_returns_df: pd.DataFrame,
    portfolio: list[dict[str, Any]],
    returns_for_weights: pd.DataFrame | None = None,
    method: str = "variance",
    zc_nominal: float = 100.0,
) -> pd.Series:
    """Construit les expositions CFM du portefeuille puis calcule le PnL."""
    cashflows = build_portfolio_cashflows(portfolio)
    mapped = map_cashflows_to_pillars(
        cashflows=cashflows,
        current_zc_price_curve=current_zc_price_curve,
        returns_for_weights=returns_for_weights,
        method=method,
        zc_nominal=zc_nominal,
    )
    exposures = aggregate_mapped_exposures(mapped, pillars=scenario_returns_df.columns)
    return compute_cfm_pnl_under_scenarios(exposures, scenario_returns_df)
