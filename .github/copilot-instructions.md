# Docker-Sonarr Custom Build

## Summary

This repository is a fork of [linuxserver/docker-sonarr](https://github.com/linuxserver/docker-sonarr) that builds a custom Sonarr Docker container (`mercu/sonarr-atomohd`) from a local Sonarr source fork instead of downloading releases from services.sonarr.tv.

- **Base image**: `ghcr.io/linuxserver/baseimage-alpine:3.23`
- **Target runtime**: `linux-musl-x64` (Alpine, self-contained .NET 10.0)
- **Docker Hub**: `mercu/sonarr-atomohd` (tag format: `amd64-YYYYMMDD`)
- **Upstream**: `https://github.com/linuxserver/docker-sonarr.git`

## Repository Layout

```
Dockerfile                  # Main build file (multi-arch: amd64/arm64)
linux-musl-x64.tar.gz      # Pre-built Sonarr backend + frontend (amd64)
linux-musl-arm64.tar.gz     # Pre-built Sonarr backend + frontend (arm64, or empty placeholder)
root/                       # s6-overlay service files (MUST have LF line endings)
  etc/s6-overlay/s6-rc.d/
    svc-sonarr/run          # Runs: /app/sonarr/bin/Sonarr -nobrowser -data=/config
.github/                    # CI workflows, issue templates
.gitattributes              # Enforces LF on root/** files
```

## Build Process (Full Rebuild)

### Prerequisites

- Sonarr source fork at `c:\temp\Sonarr` with custom changes
- .NET 10.0 SDK, Node.js (via Volta), Yarn
- Docker Desktop (linux containers mode)
- Docker Hub login (`docker login`)

### Step 1: Sync with upstream (when needed)

```powershell
cd c:\temp\docker-sonarr
git fetch upstream
git merge upstream/main
# Resolve conflicts if any, then commit
```

### Step 2: Build Sonarr backend

```powershell
cd c:\temp\Sonarr
dotnet msbuild -restore src/Sonarr.sln -p:SelfContained=true -p:Configuration=Release -p:Platform=Posix -p:RuntimeIdentifiers=linux-musl-x64 -p:EnableWindowsTargeting=true -t:PublishAllRids
```

Output: `c:\temp\Sonarr\_output_linux-musl-x64\` (all DLLs and binary at root level)

### Step 3: Build Sonarr frontend

```powershell
cd c:\temp\Sonarr
yarn install
yarn build --env production
```

Output: `c:\temp\Sonarr\_output\UI\` (webpack production build)

**Important**: The UI folder MUST be included. Without it, the web interface returns 404.

### Step 4: Create tar.gz

The tar.gz must have a `Sonarr/` top-level directory containing both the backend output and the `UI/` folder:

```powershell
$staging = "c:\temp\staging_sonarr"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path "$staging\Sonarr" | Out-Null
Copy-Item -Path "c:\temp\Sonarr\_output_linux-musl-x64\*" -Destination "$staging\Sonarr" -Recurse -Force
Copy-Item -Path "c:\temp\Sonarr\_output\UI" -Destination "$staging\Sonarr\UI" -Recurse -Force
cd $staging
tar -czf c:\temp\docker-sonarr\linux-musl-x64.tar.gz Sonarr
```

Verify:

```powershell
tar -tzf c:\temp\docker-sonarr\linux-musl-x64.tar.gz | Select-String "UI/index.html"
```

### Step 5: Build Docker image

```powershell
cd c:\temp\docker-sonarr
docker build -t mercu/sonarr-atomohd:amd64-YYYYMMDD --build-arg TARGETARCH=amd64 --no-cache -f Dockerfile .
```

### Step 6: Verify

```powershell
# Check UI exists
docker run --rm --entrypoint sh mercu/sonarr-atomohd:amd64-YYYYMMDD -c "ls /app/sonarr/bin/UI/index.html"

# Check Sonarr starts (should show FluentMigrator migrations)
docker run --rm mercu/sonarr-atomohd:amd64-YYYYMMDD
# Ctrl+C to stop
```

### Step 7: Push

```powershell
docker push mercu/sonarr-atomohd:amd64-YYYYMMDD
```

## Critical Notes & Known Issues

### Dockerfile tar extraction uses --strip-components=1

The tar.gz has a `Sonarr/` prefix (matching GitHub Actions `package.sh` format). The Dockerfile extracts with `--strip-components=1` so files land directly in `/app/sonarr/bin/`. Without this flag, the binary ends up at `/app/sonarr/bin/Sonarr/Sonarr` instead of `/app/sonarr/bin/Sonarr`.

### Sonarr.Mono.dll must be in the publish output

`AssemblyLoader.cs` dynamically loads `Sonarr.Mono` on Linux. The fix is a `<ProjectReference>` to `Sonarr.Mono.csproj` in `src/NzbDrone.Console/Sonarr.Console.csproj`. Without it: runtime crash "Could not load file or assembly 'Sonarr.Mono'".

### CRLF line endings break s6-overlay

Files under `root/` (s6 service scripts) MUST have LF line endings. Windows checkout can corrupt them. `.gitattributes` enforces `root/** text eol=lf`. If s6-rc-compile still fails, manually fix:

```powershell
Get-ChildItem root -Recurse -File | ForEach-Object {
  [System.IO.File]::WriteAllText($_.FullName, (Get-Content $_.FullName -Raw).Replace("`r`n", "`n"))
}
```

### arm64 placeholder

The Dockerfile COPYs both `linux-musl-x64.tar.gz` and `linux-musl-arm64.tar.gz`. If only building amd64, create an empty placeholder:

```powershell
New-Item linux-musl-arm64.tar.gz -ItemType File -Force
```

## Container Runtime

- s6-overlay manages services
- Sonarr binary: `/app/sonarr/bin/Sonarr`
- Frontend UI: `/app/sonarr/bin/UI/`
- Config volume: `/config`
- Port: `8989`
