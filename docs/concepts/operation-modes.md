#### Operation Modes

1. **Transfer Mode** (`modeOrExpiration = 0`)
    - Executes immediate token transfer
    - `account` is recipient
    - `amountDelta` is transfer amount

2. **Decrease Mode** (`modeOrExpiration = 1`)
    - Reduces existing allowance
    - `amountDelta`: regular decrease amount
    - Special: `type(uint160).max` resets to 0

3. **Lock Mode** (`modeOrExpiration = 2`)
    - Enters special locked state
    - Blocks increases/transfers
    - Rejects all operations until unlocked
    - Sets approval to 0 for that token/account pair

4. **Unlock Mode** (`modeOrExpiration = 3`)
    - Cancels locked state
    - Tracks unlock timestamp
    - Sets allowance to provided amount

5. **Increase Mode** (`modeOrExpiration > 3`)
    - Value acts as expiration timestamp
    - Updates if timestamp is newer
    - `amountDelta`: increase amount
    - Special cases:
        - `0`: Updates expiration only
        - `type(uint160).max`: Unlimited approval
