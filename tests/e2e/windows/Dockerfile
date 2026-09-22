# escape=`
ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64
FROM ${BASE_IMAGE}

SHELL ["powershell", "-NoProfile", "-Command"]

COPY tests/e2e/windows/bootstrap-tools.ps1 C:\bootstrap-tools.ps1

WORKDIR C:\e2e

COPY metadata.lua C:\e2e\metadata.lua
COPY hooks C:\e2e\hooks
COPY lib C:\e2e\lib
COPY tests/e2e/windows C:\e2e\tests\e2e\windows

# No ENTRYPOINT/CMD here: e2e.ps1 installs pwsh and git in a container and then
# commits it. docker commit bakes that container's entrypoint into the image, so
# e2e.ps1 sets the entrypoint explicitly for every test run.
