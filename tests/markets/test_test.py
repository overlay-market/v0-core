

def test_uni(gov, uni_test):

    uni_test.testPriceFetch({'from':gov})

    uni_test.testPriceGrab({'from':gov})