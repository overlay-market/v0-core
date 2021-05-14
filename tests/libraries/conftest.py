import pytest
from brownie import MathTest


@pytest.fixture(scope="module")
def deployer(accounts):
    yield accounts[0]


@pytest.fixture(scope="module")
def create_math(deployer):
    def create_math():
        math = deployer.deploy(MathTest)
        return math
    yield create_math


@pytest.fixture(scope="module")
def math(create_math):
    yield create_math()
