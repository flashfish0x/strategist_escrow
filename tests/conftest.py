import pytest
from brownie import Wei, config


@pytest.fixture(scope='function', autouse=True)
def shared_setup(fn_isolation):
    pass


@pytest.fixture
def whale(accounts, yfi):
    # multichain bridge
    acc = accounts.at('0xC564EE9f21Ed8A2d8E7e76c085740d5e4c5FaFbE', force=True)

    assert yfi.balanceOf(acc) > 0

    yield acc


@pytest.fixture
def yfi(interface):
    yield interface.ERC20('0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e')


@pytest.fixture
def strategist(accounts):
    yield accounts[0]


@pytest.fixture
def zero():
    yield '0x0000000000000000000000000000000000000000'


@pytest.fixture
def rando(accounts):
    yield accounts[1]


@pytest.fixture
def ychad(accounts):
    yield accounts.at('0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52', force=True)


@pytest.fixture
def releaseTime(chain):
    yield 1646732361 + (60 * 60 * 24 * 365 * 4)


@pytest.fixture
def escrow(strategist, ychad, whale, yfi, StrategistEscrow, releaseTime):
    escrow = ychad.deploy(StrategistEscrow, strategist, releaseTime)

    yfi.transfer(escrow, 50*1e18, {'from': whale})
    yield escrow
