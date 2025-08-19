# Ubuntu 24.04 GitHub Actions Runner image for k0sproject

This is a modified version of the official ARC Runner image based on commit
[0e006bb]. The following modifications were made:

- Can be built for ARMv7.
- Compiles the Actions Runner using .NET 9 ([dotnet/runtime#101444]).
- Uses `dumb-init` from the APT repositories, so that it can be installed on
  32-bit ARM.
- Add `build-essentials` to obtain a standard build environment. This includes
  `make` and enables CGO usage.
- Install `openssh-client` to include the `ssh-keygen` executable.
- Setting the environment variable `DISABLE_RUNNER_DEFAULT_LABELS` allows for
  skipping the addition of default labels by the runner.

[0e006bb]: https://github.com/actions/actions-runner-controller/tree/0e006bb0ff9094e54522cdf89c9bd5ab1806c4af/runner
[dotnet/runtime#101444]: https://github.com/dotnet/runtime/issues/101444
