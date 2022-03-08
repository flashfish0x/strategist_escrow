from itertools import count
import brownie


def test_withdraw_at_end_period(escrow, strategist, chain, yfi):

    yfiBalanceStrategist = yfi.balanceOf(strategist)

    escrow.acceptStrategist({'from': strategist})

    assert yfi == escrow.yfi()

    with brownie.reverts():
        escrow.sweep(yfi, 10000, strategist, {'from': strategist})

    chain.sleep(60 * 60 * 24 * 365 * 4)
    escrow.sweep(yfi, yfi.balanceOf(escrow), strategist, {'from': strategist})

    assert yfi.balanceOf(escrow) == 0
    assert yfi.balanceOf(strategist) > yfiBalanceStrategist


def test_agreed_migrate(escrow, strategist, ychad, chain, zero, yfi, rando):

    yfiBalanceStrategist = yfi.balanceOf(strategist)
    yfiBalanceEscrow = yfi.balanceOf(escrow)
    print(escrow.migrateTargetYchad())

    escrow.acceptStrategist({'from': strategist})

    escrow.migrate(strategist, {'from': rando})
    assert escrow.migrateTargetStrategist() == zero
    assert escrow.migrateTargetYchad() == zero
    assert yfiBalanceEscrow == yfi.balanceOf(escrow)

    escrow.migrate(strategist, {'from': strategist})
    assert escrow.migrateTargetStrategist() == strategist
    assert escrow.migrateTargetYchad() == zero
    assert yfiBalanceEscrow == yfi.balanceOf(escrow)

    escrow.migrate(strategist, {'from': ychad})
    assert escrow.migrateTargetStrategist() == strategist
    assert escrow.migrateTargetYchad() == strategist
    assert yfi.balanceOf(escrow) == 0
    assert yfiBalanceEscrow == yfi.balanceOf(strategist) - yfiBalanceStrategist
