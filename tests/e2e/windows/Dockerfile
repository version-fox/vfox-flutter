# escape=`
ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64
FROM ${BASE_IMAGE}

SHELL ["powershell", "-NoProfile", "-Command"]

COPY tests/e2e/windows/lib.ps1 C:\lib.ps1
COPY tests/e2e/windows/bootstrap-tools.ps1 C:\bootstrap-tools.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bootstrap-tools.ps1'

WORKDIR C:\e2e

COPY metadata.lua C:\e2e\metadata.lua
COPY hooks C:\e2e\hooks
COPY lib C:\e2e\lib
COPY tests/e2e/windows C:\e2e\tests\e2e\windows

ENTRYPOINT ["C:/Program Files/PowerShell/7/pwsh.exe", "-File"]
CMD ["C:/e2e/tests/e2e/windows/run.ps1"]
