# Upgradable using proxy pattern
## how it works
proxy contract holds state and delegatecall all calls to actual impl contract. When upgrade, a new impl contract is deployed, and proxy is updated to point to the new contract. below from [openzeppelin doc](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#upgrading-via-the-proxy-pattern)
```
User ---- tx ---> Proxy ----------> Implementation_v0
                     |
                      ------------> Implementation_v1
                     |
                      ------------> Implementation_v2

```

## to be upgradable, contract must:
1. no constructor, openzeppelin uses initialize by default. must manually call parent contract initialize
2. use openzeppelin/contracts-upgradeable
3. no immutable variables as they are calculated in construction and saved directly into bytecode
4. future changes must keep storage compatible. Operations such as reordering variables, inserting new variables, changing the type of a variable, or even changing the inheritance chain of a contract can potentially break storage. The only safe change is to append state variables after any existing ones.