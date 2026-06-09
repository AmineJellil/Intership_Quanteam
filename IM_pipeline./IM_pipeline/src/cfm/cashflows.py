"""Extraction des cash-flows pour portefeuilles obligataires à taux fixe."""

from __future__ import annotations

from typing import Any

import pandas as pd


def generate_fixed_rate_bond_cashflows(
    position: dict[str, Any],
    position_id: int | str | None = None,
) -> pd.DataFrame:
    """Génère les cash-flows futurs signés d'une position obligataire.

    La CFM en a besoin explicitement, car chaque cash-flow doit être mappé sur les piliers
    adjacents de la courbe avant le calcul du PnL sous scénarios.
    """
    maturity = float(position["maturity"])
    frequency = int(position.get("frequency", 1))
    nominal = float(position.get("nominal", 100.0))
    coupon_rate = float(position["coupon_rate"])
    quantity = float(position.get("quantity", 1.0))

    if maturity <= 0:
        raise ValueError(f"maturity doit être positive, reçu {maturity}")
    if frequency <= 0:
        raise ValueError(f"frequency doit être positive, reçu {frequency}")

    coupon = nominal * coupon_rate / frequency
    dt = 1.0 / frequency

    payment_times: list[float] = []
    t = maturity
    while t > 1e-6:
        payment_times.append(t)
        t -= dt
    payment_times = sorted(payment_times)

    rows = []
    for i, payment_time in enumerate(payment_times):
        cashflow = coupon
        if i == len(payment_times) - 1:
            cashflow += nominal

        rows.append(
            {
                "position_id": position_id,
                "instrument": position.get("name", f"position_{position_id}"),
                "maturity": float(payment_time),
                "cashflow": quantity * cashflow,
                "cashflow_unit": cashflow,
                "quantity": quantity,
            }
        )

    return pd.DataFrame(rows)


def build_portfolio_cashflows(portfolio: list[dict[str, Any]]) -> pd.DataFrame:
    """Génère la table des cash-flows signés d'un portefeuille obligataire."""
    frames = [
        generate_fixed_rate_bond_cashflows(position, position_id=i)
        for i, position in enumerate(portfolio)
    ]
    if not frames:
        return pd.DataFrame(
            columns=[
                "position_id",
                "instrument",
                "maturity",
                "cashflow",
                "cashflow_unit",
                "quantity",
            ]
        )
    return pd.concat(frames, ignore_index=True)
