using module "./python-builder.psm1"

class WinPythonBuilder : PythonBuilder {
    <#
    .SYNOPSIS
    Base Python builder class for Windows systems.

    .DESCRIPTION
    Contains methods required for build Windows Python artifact. Inherited from base PythonBuilder class.

    .PARAMETER version
    The version of Python that should be built.

    .PARAMETER architecture
    The architecture with which Python should be built.

    .PARAMETER InstallationTemplateName
    The name of installation script template that will be used in generated artifact.

    .PARAMETER InstallationScriptName
    The name of generated installation script.

    #>

    [string] $InstallationTemplateName
    [string] $InstallationScriptName
    [string] $OutputArtifactName
    [bool] $UseNuGet

    WinPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) {
        if ($this.IsFreeThreaded()) {
            $this.UseNuGet = $true
        }
        else {
            $this.UseNuGet = $false
        }
        if ($this.UseNuGet) {
            $this.InstallationTemplateName = "win-nuget-template.ps1"
        }
        else {
            $this.InstallationTemplateName = "win-setup-template.ps1"
        }
        $this.InstallationScriptName = "setup.ps1"
        $this.OutputArtifactName = "python-$Version-$Platform-$Architecture.zip"
    }

    [string] GetPythonExtension() {
        <#
        .SYNOPSIS
        Return extension for required version of Python executable.
        #>

        $extension = if ($this.Version -lt "3.5" -and $this.Version -ge "2.5") { ".msi" } else { ".exe" }

        return $extension
    }

    [string] GetArchitectureExtension() {
        <#
        .SYNOPSIS
        Return architecture suffix for Python executable.
        #>

        $ArchitectureExtension = ""
        if ($this.GetHardwareArchitecture() -eq "x64") {
            if ($this.Version -ge "3.5") {
                $ArchitectureExtension = "-amd64"
            } else {
                $ArchitectureExtension = ".amd64"
            }
        } elseif ($this.GetHardwareArchitecture() -eq "arm64") {
                $ArchitectureExtension = "-arm64"
        }

        return $ArchitectureExtension
    }

    [uri] GetSourceUri() {
        <#
        .SYNOPSIS
        Get base Python URI and return complete URI for Python installation executable.
        #>

        $base = $this.GetBaseUri()
        $versionName = $this.GetBaseVersion()
        $nativeVersion = Convert-Version -version $this.Version
        $architecture = $this.GetArchitectureExtension()
        $extension = $this.GetPythonExtension()

        $uri = "${base}/${versionName}/python-${nativeVersion}${architecture}${extension}"

        return $uri
    }

    [string] GetNuGetPackageName() {
        $packageName = "python"
        $arch = $this.GetHardwareArchitecture()
        if ($arch -ne "x64") {
            $packageName = "${packageName}${arch}"
        }
        if ($this.IsFreeThreaded()) {
            $packageName = "${packageName}-freethreaded"
        }
        return $packageName
    }

    [void] Download() {
        <#
        .SYNOPSIS
        Download Python installation executable into artifact location.
        #>
        if ($this.UseNuGet) {
            $packageName = $this.GetNuGetPackageName()
            $version = $this.Version
            $tempDir = Join-Path -Path $this.WorkFolderLocation -ChildPath "Temp"
            $versionDir = Join-Path -Path $tempDir -ChildPath "${packageName}.${version}"
            $toolsDir = Join-Path -Path $versionDir -ChildPath "tools"
            Install-Package -ProviderName "NuGet" -Name $packageName -RequiredVersion $this.Version -Destination $tempDir -Confirm:$false -Force
            Move-Item -Path "${toolsDir}\*" -Destination $this.WorkFolderLocation
            Remove-Item -Path $tempDir -Force -Recurse
        }
        else {
            $sourceUri = $this.GetSourceUri()
            Write-Host "Sources URI: $sourceUri"
            $sourcesLocation = Download-File -Uri $sourceUri -OutputFolder $this.WorkFolderLocation
            Write-Debug "Done; Sources location: $sourcesLocation"
        }
    }

    [void] CreateInstallationScript() {
        <#
        .SYNOPSIS
        Create Python artifact installation script based on specified template.
        #>

        if ($this.UseNuGet) {
            $pythonExecName = ""
        }
        else {
            $sourceUri = $this.GetSourceUri()
            $pythonExecName = [IO.path]::GetFileName($sourceUri.AbsoluteUri)
        }
        $installationTemplateLocation = Join-Path -Path $this.InstallationTemplatesLocation -ChildPath $this.InstallationTemplateName
        $installationTemplateContent = Get-Content -Path $installationTemplateLocation -Raw
        $installationScriptLocation = New-Item -Path $this.WorkFolderLocation -Name $this.InstallationScriptName -ItemType File

        $variablesToReplace = @{
            "{{__ARCHITECTURE__}}" = $this.Architecture;
            "{{__HARDWARE_ARCHITECTURE__}}" = $this.GetHardwareArchitecture();
            "{{__VERSION__}}" = $this.Version;
            "{{__PYTHON_EXEC_NAME__}}" = $pythonExecName
        }

        $variablesToReplace.keys | ForEach-Object { $installationTemplateContent = $installationTemplateContent.Replace($_, $variablesToReplace[$_]) }
        $installationTemplateContent | Out-File -FilePath $installationScriptLocation
        Write-Debug "Done; Installation script location: $installationScriptLocation)"
    }

    [void] ArchiveArtifact() {
        $OutputPath = Join-Path $this.ArtifactFolderLocation $this.OutputArtifactName
        Create-SevenZipArchive -SourceFolder $this.WorkFolderLocation -ArchivePath $OutputPath
    }

    [void] Build() {
        <#
        .SYNOPSIS
        Generates Python artifact from downloaded Python installation executable.
        #>

        Write-Host "Download Python $($this.Version) [$($this.Architecture)] executable..."
        $this.Download()

        Write-Host "Create installation script..."
        $this.CreateInstallationScript()

        Write-Host "Archive artifact"
        $this.ArchiveArtifact()
    }
}
