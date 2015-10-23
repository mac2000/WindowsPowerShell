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

# Modules

ConvertTo-Markdown
==================



ConvertTo-Markdown
------------------

Converts a PowerShell object to a Markdown table.

        $data | ConvertTo-Markdown
        ConvertTo-Markdown($data)





ConvertTo-TabbedList
====================



ConvertTo-TabbedList
--------------------

Converts a PowerShell object to a Tabbed list which can be copied to Excel.

        $data | ConvertTo-TabbedList | clip
        ConvertTo-TabbedList($data)





Generate-Readme
===============



Generate-Readme
---------------

Generate markdown readme with module descriptions and usage examples

        Generate-Readme





HelloWorld
==========



Say-Hello
---------

PowerShell Module StarterKit

        Say-Hello
        Say-Hello -To Alexandr





PasswordVault
=============



Get-VaultCredential
-------------------

Retrieves credentials stored in the current user's PasswordVault. It will either return all stored credentials
or a subset meeting the passed in criteria

        #get all credentials stored in the vault for the current user
        Get-VaultCredential -Resolve
        #get all credentials with the user name "fakeuser@microsoft.com" stored in the vault for the current user
        Get-VaultCredential -UserName "fakeuser@microsoft.com" -Resolve



Add-VaultCredential
-------------------

Adds a credential, associated with a particular resource, to the current user's PasswordVault.

        #Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
        $added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough
        #Visually verify the credentials have been stored
        Get-VaultCredential -UserName TestUser
        #Add a credential for a website login
        Add-VaultCredential -Resource "https://www.outlook.com" -UserName "fakeuser@microsoft.com"



Remove-VaultCredential
----------------------

Removes the specified credentials from the PasswordVault store

        #Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
        $added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough
        #visually verify that they have been stored
        Get-VaultCredential -UserName TestUser
        #Delete the newly created test credentials
        $added | Remove-VaultCredential



ConvertTo-Credential
--------------------

Converts a PasswordVault credential to a standard Powershell credential

        #Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
        $added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough
        #convert all new test PasswordVault credentials to Powershell credentials
        $added | ConvertTo-Credential
        #Get a credential from the PasswordVault that is associated with Powershell remoting and use it to execute a command on a remote host
        #Note the url protocol used as the resource name is fictitious and used solely for identification
        #The converted credential will have a Resource note property attached
        $credential = Get-VaultCredential -Resource "psrp://MyServer.microsoft.com" -UserName "fakeuser" | ConvertTo-Credential
        Invoke-Command -Credential $credential -ComputerName ($credential.Resource.split("//")[2]) -ScriptBlock { write-host -f green "Hello from $env:COMPUTERNAME" }



ConvertTo-VaultCredential
-------------------------

Converts a standard Powershell credential to a PasswordVault credential. An associated resource
must be specified for the credential if the credential was not created with the corresponding
command ConvertTo-Credential

        #Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
        $added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough
        #convert the PasswordVault credentials to standard Powershell credentials, and back again
        $added | ConvertTo-Credential | ConvertTo-VaultCredential
