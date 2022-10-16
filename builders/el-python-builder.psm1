using module "./nix-python-builder.psm1"

class EnterpriseLinuxPythonBuilder : NixPythonBuilder {
    <#
    .SYNOPSIS
    Enterprise Linux Python builder class.

    .DESCRIPTION
    Contains methods that required to build Enterprise Linux Python artifact from sources. Inherited from base NixPythonBuilder.

    .PARAMETER platform
    The full name of platform for which Python should be built.

    .PARAMETER version
    The version of Python that should be built.

    #>

    EnterpriseLinuxPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) { }

    [void] Configure() {
        <#
        .SYNOPSIS
        Execute configure script with required parameters.
        #>

        $pythonBinariesLocation = $this.GetFullPythonToolcacheLocation()

        ### To build Python with SO we must pass full path to lib folder to the linker
        $env:LDFLAGS="-Wl,--rpath=${pythonBinariesLocation}/lib"
        $configureString = "./configure"
        $configureString += " --prefix=$pythonBinariesLocation"
        $configureString += " --enable-shared"
        $configureString += " --enable-optimizations"

        ### Compile with ucs4 for Python 2.x. On 3.x, ucs4 is enabled by default
        if ($this.Version -lt "3.0.0") {
            $configureString += " --enable-unicode=ucs4"
        }

        ### Compile with support of loadable sqlite extensions. Unavailable for Python 2.*
        ### Link to documentation (https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.enable_load_extension)
        if ($this.Version -ge "3.2.0") {
            $configureString += " --enable-loadable-sqlite-extensions"
        }

        Write-Host "The passed configure options are: "
        Write-Host $configureString

        Execute-Command -Command $configureString
    }

    [void] PrepareEnvironment() {
        <#
        .SYNOPSIS
        Prepare system environment by installing dependencies and required packages.
        #>

        if (($this.Version -gt "3.0.0") -and ($this.Version -lt "3.5.3")) {
            Write-Host "Python3 versions lower than 3.5.3 are not supported"
            exit 1
        }
    }
}
