---
name: xiaomi-mimo-balance
description: 'Check Xiaomi MiMo platform account balance. Use this skill whenever the user asks to check their MiMo balance, view Xiaomi AI platform credits, or says things like 查余额, 看看余额, mimo余额, 小米余额, 还剩多少钱. Also trigger on balance check for xiaomi platform or xiaomimimo.'
disable-model-invocation: false
user-invocable: true
---

# Xiaomi MiMo Balance Checker

Open the Xiaomi MiMo platform balance page and report the account balance as simple text.

## Steps

1. Open the browser to `https://platform.xiaomimimo.com/console/balance`
2. Take a snapshot of the page (use `compact: true` to keep it readable)
3. Extract the balance information from the snapshot — look for these fields:
   - **总余额** (total balance)
   - **现金余额** (cash balance)
   - **赠送余额** (bonus/gift balance)
4. Report to the user in a single concise message, e.g.:
   > 你的 MiMo 账户余额：¥13.66（现金 ¥10.00 + 赠送 ¥3.66）

If the page shows a login screen instead of balance info, tell the user they need to log in first via the browser.

If there are important notices (like service migration or deprecation warnings), briefly mention them after the balance.
