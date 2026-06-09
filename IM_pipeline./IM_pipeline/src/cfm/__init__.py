"""Cash-Flow Mapping (CFM) engine for initial margin calculations."""

from src.cfm.cashflows import build_portfolio_cashflows, generate_fixed_rate_bond_cashflows
from src.cfm.mapping import aggregate_mapped_exposures, map_cashflows_to_pillars
from src.cfm.pnl import compute_cfm_pnl_under_scenarios, compute_portfolio_pnl_cfm

__all__ = [
    "aggregate_mapped_exposures",
    "build_portfolio_cashflows",
    "compute_cfm_pnl_under_scenarios",
    "compute_portfolio_pnl_cfm",
    "generate_fixed_rate_bond_cashflows",
    "map_cashflows_to_pillars",
]
