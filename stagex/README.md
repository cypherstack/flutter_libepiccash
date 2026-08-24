# StageX build

This is a StageX `user` package definition for the native Linux Epic Cash
library. It targets StageX commit
`9bdf430d09ce2ba53932df0182faef00d4feecd1`; `stagex.lock` records the
expected amd64 dependency-image digests.

Copy this directory to `packages/user/stack-wallet-epiccash` in a checkout of
that StageX revision, add it to the Git index, then run:

```sh
make fetch PKG=stack-wallet-epiccash
make user-stack-wallet-epiccash NOCACHE=1
python3 src/package-digests.py user-stack-wallet-epiccash
```

The plugin and both levels of its RandomX Git submodule are independently
SHA-256 locked. Cargo resolves the remaining crates and Git dependencies from
`Cargo.lock`; compilation then runs offline. Reproduce independently and
compare the image digest.
