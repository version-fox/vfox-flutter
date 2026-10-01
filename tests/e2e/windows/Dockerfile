# escape=`
ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64
FROM ${BASE_IMAGE}

SHELL ["powershell", "-NoProfile", "-Command"]

COPY tests/e2e/windows/bootstrap-tools.ps1 C:\bootstrap-tools.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bootstrap-tools.ps1'

WORKDIR C:\e2e

COPY metadata.lua C:\e2e\metadata.lua
COPY hooks C:\e2e\hooks
COPY lib C:\e2e\lib

# Long-lived container: the Go test (e2e_test.go) drives every phase through
# pwsh exec calls, so the main process just idles here.
ENTRYPOINT ["C:/Program Files/PowerShell/7/pwsh.exe", "-NoProfile", "-Command"]
CMD ["while ($true) { Start-Sleep 3600 }"]
