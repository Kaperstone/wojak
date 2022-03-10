# Setup

- Create liquidity pool beforehand

Setup is very easy, give `manager` contract `DEFAULT_ADMIN_ROLE` role for all contracts
and let it do its job, which is to sync all contracts.

# Treasury
Our `PCV - Protocol Controlled Value` man

## Add new strategy
Treasury is designed to work with `soyfarms`, thus, if your strategy doesn't match the same design,
the treasury won't work with it
The function `treasury.addStrategy` is the function you're looking for if you want to add a new one.
That's all you need to do.

## Disable strategy (maybe permenantly)
If you want to stop a strategy/token to function, use `disableStrategy` and you're done 

## Change strategy
`changeStrategy` will withdraw from the old one, change the strategy address and deposit in the new contract.
@caution: will put the token to work instantly.

## Re-enable strategy
If you regret disabling a strategy or decided for some reason that you want to re-enable a strategy
use `enableStrategy` and you're fine boi.

## Leave a token for good and sell all its tokens
Want to leave a market? did the platform got on your nerves? you're done with it? faught with their devs? Its crumbling to tears? they hacked and fell?

Happy news, you can leave the market, sell of the tokens that your token bought from them and instead of leaving the tokens to eat dust, you can send them to other strategies

Use `exitAndBalanceMarkets` and you're done

## Leave a token, but plan to replace it with another platform and want to preserve the tvl
You use `exitMarket`, it will convert the tokens to `USDC` and put them to work at the appropriate `soyfarm`
When you decide on your new market, use `enterMarket` for the new market.

## other functions which you shouldn't use
`fillBonds` is one of them, leave it for `keeper` contract to play with it

`deposit` unless you want to donate ;)




# Locker
Ahh our smartest and most modular contract
Just use `depositToBank` to send any tokens you want to deposit, and the contract will do the rest
with the distribution.
Zero interaction beyond `manager` setup.

Can be a good tool to create "fair launch"


# Bonds
# Keeper
# Wojak
Nothing special, this is just an IERC20 with mint() and burn() functionality.

# Zoomer & Boomer
The difference: Zoomer is meant to be used with `soyfarms` exclusively, and thus you need `CONTRACT_ROLE` permissions to use it.
Boomer is the main, global staking contract