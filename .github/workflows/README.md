# GitHub Actions status

SariSupply repository verification is intentionally repository-owned through `tool/verify_harness.sh`.

An active Actions workflow is not committed yet because earlier workflows returned GitHub `startup_failure` before a runner was allocated. Reintroducing an active workflow before that account/repository issue is resolved would make the branch permanently red without providing useful verification.

A CI-ready example is stored at:

`docs/engineering/github-actions-verify.example.yml`

When Actions becomes available:

1. copy the example to `.github/workflows/verify.yml`;
2. run it on a test PR;
3. confirm the harness passes on the hosted runner;
4. only then make the check required for merge.

Do not duplicate verification logic in YAML. CI should call repository scripts.
