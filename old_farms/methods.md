# Investing methods
>@SCERAM: Length(18) platform(self)
Contract: 0xe3D17C7e840ec140a7A51ACA351a482231760824
    SCREAM.deposit(uint amount)
    SCREAM.withdraw(uint _share)
Profit: (_share * scream.totalBalance / xscream.totalSupply)

>@BOO: Length(18) platform(self)
Contract: 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598
    XBOO.enter(uint amount)
    XBOO.leave(uint _share)
Profit: _xBOOForBOO(uint _xBOOAmount) - booBalance

>@TAROT: length(18) platform(self)
Contract: 0x74D1D2A851e339B8cB953716445Be7E8aBdf92F4
    XTAROT.enter(uint amount)
    XTAROT.leave(uint _share)
Profit: underlyingBalanceForAccount(address _account) - tarotBalance

# Cancelled ideas

-@CRV: length(18) platform(scream)
Contract: 
    scCRV.mint(uint mintAmount)
    scCRV.redeemUnderlying(uint redeemTokens)
Profit: balanceOfUnderlying(address owner) - crvBalance

-@SPELL: length(18) platform(scream)
Contract: 0xB19b33fFf3A9B21F120B6aC585b8ce21635BEb96
    scSPELL.mint(uint mintAmount)
    scSPELL.redeemUnderlying(uint redeemTokens)
Profit: balanceOfUnderlying(address owner) - spellBalance

-@BIFI: length(18) platform(scream)
Contract: 0x0467c22fB5aF07eBb14C851C75bFf4180674Ed64
    scBIFI.mint(uint mintAmount)
    scBIFI.redeemUnderlying(uint redeemTokens)
Profit: balanceOfUnderlying(address owner) - spellBalance
-BEETS: length(18)
Contract: 0xfcef8a994209d6916EB2C86cDD2AFD60Aa6F54b1
    FBEETS.enter(uint amount)
    FBEETS.leave(uint _shareOfFreshBeets)

-MOO: length(18)
Contract: 0xbF07093ccd6adFC3dEB259C557b61E94c1F66945
    MOO.deposit(uint amount)
    MOO.withdraw(uint _share)