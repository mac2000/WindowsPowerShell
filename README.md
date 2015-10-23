# WindowsPowerShell

Some of my cmdlets

## Installation

    cd %USERPROFILE%\Documents
    git clone https://github.com/mac2000/WindowsPowerShell.git


## TODO: Publishing to PowerShell Gallery

    New-ModuleManifest -Path 'C:\Users\Alexandr\Documents\WindowsPowerShell\Modules\HelloWorld\HelloWorld.psd1'
    Publish-Module -Name HelloWorld -NuGetApiKey '********-****-****-****-************'
    Find-Module -Name HelloWorld
    Install-Module HelloWorld