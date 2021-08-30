from brownie import reverts, chain
from brownie.test import given, strategy



def test_sanity(overlay_oi):

    cardinality = overlay_oi.cardinality()
    cardinality_next = overlay_oi.cardinalityNext()
    index = overlay_oi.index()

    assert cardinality == 1
    assert cardinality_next == 1
    assert index == 0

def test_expand_cardinality_next(overlay_oi):

    prior_index = overlay_oi.index()
    prior_cardinality = overlay_oi.cardinality()
    prior_cardinality_next = overlay_oi.cardinalityNext()

    overlay_oi.expand(prior_cardinality_next + 1)

    next_index = overlay_oi.index() 
    next_cardinality = overlay_oi.cardinality()
    next_cardinality_next = overlay_oi.cardinalityNext()

    assert next_index == prior_index
    assert next_cardinality == prior_cardinality
    assert next_cardinality_next == prior_cardinality_next + 1

def test_roller(overlay_oi):

    print(overlay_oi)