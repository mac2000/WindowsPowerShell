#################################################################################   
# The sample scripts are not supported under any Microsoft standard support  
# program or service. The sample scripts are provided AS IS without warranty 
# of any kind. Microsoft further disclaims all implied warranties including,  
# without limitation, any implied warranties of merchantability or of fitness for  
# a particular purpose. The entire risk arising out of the use or performance of  
# the sample scripts and documentation remains with you. In no event shall 
# Microsoft, its authors, or anyone else involved in the creation, production, or
# delivery of the scripts be liable for any damages whatsoever (including,
# without limitation, damages for loss of business profits, business interruption,  
# loss of business information, or other pecuniary loss) arising out of the use
# of or inability to use the sample scripts or documentation, even if Microsoft  
# has been advised of the possibility of such damages  
##################################################################################  

#Requires -Version 3.0

#*** To be trustworthy in a production environment, this module would need to be signed and the execution policy set to verify that signature ***
#*** TODO: Create a format specifier that prevents the retrieved plaintext passwords from being displayed on the screen by default ***
#Editor: VS2013

#region Initialization
try
{
	#Load the WinRT projection for the PasswordVault
	$Script:vaultType = [Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
	$Script:vault	  = new-object Windows.Security.Credentials.PasswordVault -ErrorAction silentlycontinue
}
catch
{
	throw "This module relies on functionality provided in Windows 8 or Windows 2012 and above."
}
#endregion

#region PasswordVault events
#Add Powershell events to support performing actions when the vault has
#changes made by this module
$script:EventSender		 = "PasswordVault"
$script:AddIdentifier	 = "AddVaultCredential"
$script:RemoveIdentifier = "RemoveVaultCredential"

#When fan out remoting to perform actions, assuming that the events should
#be forwarded to the hub by default
$script:AddIdentifier,
$script:RemoveIdentifier |
	foreach-Object {      
        #When using the standard Powershell remote host, the host name is ServerRemoteHost.
		#There might be a more reliable way to perform this detection
        if ($host.name -eq "ServerRemoteHost")
        {
			#remove any subscriber within the remote host. Typically this would be encountered
			#when someone performs import-module -force to reload the module
			if (Get-EventSubscriber -SourceIdentifier $_ -Force -ErrorAction silentlycontinue)
			{
				Unregister-Event -Force -SourceIdentifier $_ 
			}

            #if there is multiple levels of remoting being used, as long as
            #the event is registered for forwarding at each level, the event
            #will make it back to the central machine
            Register-EngineEvent -SourceIdentifier $_ -Forward
        }
	}
#endregion

function Get-VaultCredential
{
	<#
		.SYNOPSIS
			Retrieves credentials stored in the current user's PasswordVault. It will either return all stored credentials
			or a subset meeting the passed in criteria
						
		.PARAMETER Resource
   			The resource to locate credentials for in the PasswordVault
		.PARAMETER UserName
   			The user name to locate credentials for in the PasswordVault
		.PARAMETER Resolve
   			Resolves the password (if stored) when retrieving the credential. If you specify the username and resource, the
			password is always resolved
		
		.EXAMPLE
			#get all credentials stored in the vault for the current user
			Get-VaultCredential -Resolve
		.EXAMPLE
			#get all credentials with the user name "fakeuser@microsoft.com" stored in the vault for the current user
			Get-VaultCredential -UserName "fakeuser@microsoft.com" -Resolve
		
		.NOTES
			Author: Tim Bertalot
	#> 
	
	[CmdletBinding(  
		RemotingCapability		= "Powershell", 
		SupportsShouldProcess   = $false,
		ConfirmImpact           = "High", #High because some of the vault retrieval methods will auto populate the plaintext password
		DefaultParameterSetName = ""
	)]
	
	[OutputType([Windows.Security.Credentials.PasswordCredential])]
	 
	param
	(
		[Parameter(
			HelpMessage						= "Enter the resource of the vault credential to retrieve",
			Position						= 0,
			ValueFromPipeline				= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[String]
		$Resource,		

		[Parameter(
			HelpMessage						= "Enter the user name of the vault credential to retrieve",
			Position						= 1,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[Alias("UN","Name","AccountName")]
		[String]
		$UserName,

		[switch]
		$Resolve
	)

	begin
	{
		$cmdName = (Get-PSCallStack)[0].Command
		Write-Debug "[$cmdName] Entering function"
	}
	
	process
	{
		try
		{
			&{
				if ($Resource -and $UserName)
				{
					#unfortunately, the Retrieve() method automatically resolves the cleartext password
					$Script:vault.Retrieve($Resource,$UserName)
				}
				elseif ($Resource)
				{
					$Script:vault.FindAllByResource($Resource)
				}
				elseif ($UserName)
				{
					$Script:vault.FindAllByUserName($UserName)
				}
				else
				{
					$Script:vault.RetrieveAll()
				}
			} | foreach-Object { if($Resolve){ $_.RetrievePassword() }; $_ }
		}
		catch
		{
			Write-Error -ErrorRecord $_ -RecommendedAction "Check your search input - user: $UserName resource: $Resource"
		}
	}
	
	end
	{
		Write-Debug "[$cmdName] Exiting function"
	}
}

function Add-VaultCredential
{
	<#
		.SYNOPSIS
			Adds a credential, associated with a particular resource, to the current user's PasswordVault. 
			
		.PARAMETER Resource
   			The resource the credential is associated with. This is commonly a website URL
		.PARAMETER UserName
   			The user name to associate with the resource and store in the PasswordVault
		.PARAMETER Password
   			The password to associate with the resource and store in the PasswordVault
		.PARAMETER PassThrough
   			Passes the created the created credential into the pipeline
		
		.EXAMPLE
			#Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
			$added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough

			#Visually verify the credentials have been stored
			Get-VaultCredential -UserName TestUser
		.EXAMPLE
			#Add a credential for a website login
			Add-VaultCredential -Resource "https://www.outlook.com" -UserName "fakeuser@microsoft.com"
		
		.NOTES
			Author: Tim Bertalot

			MSDN mentioned the limitation below it appears the limit is 2048 entries:
			"You can only store up to ten credentials per app in the Credential Locker. If you try to store more than ten credentials, you will encounter an Exception."
	#> 
	
	[CmdletBinding(  
		RemotingCapability		= "Powershell",
		SupportsShouldProcess   = $true,
		ConfirmImpact           = "Low",
		DefaultParameterSetName = ""
	)]
	
	[OutputType([Windows.Security.Credentials.PasswordCredential])]
	 
	param
	(
		[Parameter(
			HelpMessage						= "Enter the resource the credential applies to",
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipeline				= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[String[]]
		$Resource,

		[Parameter(
			HelpMessage						= "Enter the user name(s) to add",
			Position						= 1,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[Alias("UN","Name","AccountName")]
		[String]
		$UserName,

		[Parameter(
			HelpMessage						= "Enter the password for the user name",
			Position						= 2,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[SecureString]
		$Password,

		[Alias("PassThru")]
		[switch]
		$PassThrough
	)

	begin
	{
		$cmdName = (Get-PSCallStack)[0].Command
		Write-Debug "[$cmdName] Entering function"
	}
	
	process
	{
		foreach ($item in $Resource)
		{
			if ($pscmdlet.ShouldProcess("User: $UserName Resource: $item"))
			{
				$insecurePassword = $credential = $null
				try
				{
					#The PasswordVault credential constructor does not accept a securestring
					$insecurePassword = ConvertTo-PlainText $Password
					$credential = new-object Windows.Security.Credentials.PasswordCredential $item,$UserName,$insecurePassword
					write-Verbose "Adding credential with user: $UserName for resource $item"
					$Script:vault.Add($credential)
					#fire Powershell event in case something needs to take action on this add
					$null = New-Event -Sender $script:EventSender -SourceIdentifier $AddIdentifier -MessageData @{ Action = "Added"; UserName = $UserName; Resource = $item }

					if ($PSBoundParameters.PassThrough) { $credential }
				}
				catch
				{
					Write-Error -ErrorRecord $_ -RecommendedAction "Verify your inputted credential information - user: $UserName resource: $item"
				}
				finally
				{
					remove-Variable -Force -Confirm:$false -Name insecurePassword,credential
				}
			}
		}
	}
	
	end
	{
		#Due diligence to get plaintext password(s) out of managed memory
		[gc]::Collect()

		Write-Debug "[$cmdName] Exiting function"
	}
}

function Remove-VaultCredential
{
	<#
		.SYNOPSIS
			Removes the specified credentials from the PasswordVault store
						
		.PARAMETER Resource
   			The resource associated with the credential to remove from the PasswordVault. This is commonly a website URL
		.PARAMETER UserName
   			The user name associated with the credential to remove from the PasswordVault
		.PARAMETER VaultCredential
   			The PasswordVault credential object to remove from the vault
		
		.EXAMPLE
			#Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
			$added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough

			#visually verify that they have been stored
			Get-VaultCredential -UserName TestUser

			#Delete the newly created test credentials
			$added | Remove-VaultCredential
		
		.NOTES
			Author: Tim Bertalot
	#> 
	
	[CmdletBinding(  
		RemotingCapability		= "Powershell", 
		SupportsShouldProcess   = $true,
		ConfirmImpact           = "Medium",
		DefaultParameterSetName = "UserName"
	)]
		 
	param
	(
		[Parameter(
			ParameterSetName				= "UserName",
			HelpMessage						= "Enter the resource of the vault credential to remove",
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipeline				= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[String]
		$Resource,

		[Parameter(
			ParameterSetName				= "UserName",
			HelpMessage						= "Enter the user name of the vault credential to remove",
			Position						= 1,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[Alias("UN","Name","AccountName")]
		[String]
		$UserName,

		[Parameter(
			ParameterSetName				= "VaultCredential",
			HelpMessage						= "Provide the PasswordVault credential object to remove",
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipeline				= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[Alias("PasswordCredential")]
		[ValidateNotNull()]
		[Windows.Security.Credentials.PasswordCredential]
		$VaultCredential
	)

	begin
	{
		$cmdName = (Get-PSCallStack)[0].Command
		Write-Debug "[$cmdName] Entering function"
	}
	
	process
	{
		#get the values for the confirmation prompt
		if ($PSBoundParameters.VaultCredential)
		{
			$UserName = $VaultCredential.UserName
			$Resource = $VaultCredential.Resource
		}

		if ($pscmdlet.ShouldProcess("User: $UserName Resource: $Resource"))
		{
			if ($PSBoundParameters.UserName)
			{
				#Finds the credential object in the store in order for it to be removed
				$VaultCredential = Get-VaultCredential -UserName $UserName -Resource $Resource -EA SilentlyContinue
			}

			if ($VaultCredential)
			{
				try
				{
					write-Verbose "Removing credential User: $UserName Resource: $Resource from the PasswordVault"
					$Script:vault.Remove($VaultCredential)
					#fire Powershell event in case something needs to take action on this removal
					$null = New-Event -Sender $script:EventSender -SourceIdentifier $RemoveIdentifier -MessageData @{ Action = "Removed"; UserName = $UserName; Resource = $Resource }
				}
				catch
				{
					Write-Error -ErrorRecord $_ -RecommendedAction "Verify your inputted credential information - User: $UserName Resource: $Resource from the PasswordVault"
				}
			}
			else
			{
				write-Error "Could not locate credential User: $UserName Resource: $Resource in the vault in order to remove it"
			}
		}
	}
	
	end
	{
		Write-Debug "[$cmdName] Exiting function"
	}
}

function ConvertTo-Credential
{
	<#
		.SYNOPSIS
			Converts a PasswordVault credential to a standard Powershell credential
						
		.PARAMETER VaultCredential
   			The PasswordVault credential to convert to a Powershell credential
		
		.EXAMPLE
			#Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
			$added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough

			#convert all new test PasswordVault credentials to Powershell credentials
			$added | ConvertTo-Credential
		.EXAMPLE
			#Get a credential from the PasswordVault that is associated with Powershell remoting and use it to execute a command on a remote host
			#Note the url protocol used as the resource name is fictitious and used solely for identification
			#The converted credential will have a Resource note property attached
			$credential = Get-VaultCredential -Resource "psrp://MyServer.microsoft.com" -UserName "fakeuser" | ConvertTo-Credential
			Invoke-Command -Credential $credential -ComputerName ($credential.Resource.split("//")[2]) -ScriptBlock { write-host -f green "Hello from $env:COMPUTERNAME" }
		
		.NOTES
			Author: Tim Bertalot
	#> 
	
	[CmdletBinding(  
		RemotingCapability		= "Powershell",
		SupportsShouldProcess   = $false,
		ConfirmImpact           = "None",
		DefaultParameterSetName = ""
	)]
	
	[OutputType([System.Management.Automation.PSCredential])]
	 
	param
	(
		[Parameter(
			HelpMessage						= "Provide the PasswordVault credential to convert to a Powershell credential",
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipeline				= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[Alias("PasswordCredential","Credential")]
		[Windows.Security.Credentials.PasswordCredential[]]
		$VaultCredential
	)

	begin
	{
		$cmdName = (Get-PSCallStack)[0].Command
		Write-Debug "[$cmdName] Entering function"
	}
	
	process
	{
		foreach ($credential in $PSBoundParameters.VaultCredential)
		{
			try
			{
				#Ensures the password property is populated
				$credential.RetrievePassword()

				#attach a note property with what resource the credential applies to so there technically isn't any information loss
				new-Object System.Management.Automation.PSCredential $credential.UserName,(ConvertTo-SecureString -Force -AsPlainText $credential.Password) |
					add-Member -PassThru -Force -NotePropertyName Resource -NotePropertyValue $credential.Resource
			}
			catch
			{
				Write-Error -ErrorRecord $_ 
			}
		}
	}
	
	end
	{
		Write-Debug "[$cmdName] Exiting function"
	}
}

function ConvertTo-VaultCredential
{
	<#
		.SYNOPSIS
			Converts a standard Powershell credential to a PasswordVault credential. An associated resource
			must be specified for the credential if the credential was not created with the corresponding
			command ConvertTo-Credential
						
		.PARAMETER Resource
   			The resource the credential is associated with. This is commonly a website URL
		.PARAMETER UserName
   			The user name of the Powershell credential to convert. This would typically be 
			bound by property name when pipelineing credentials output by ConvertTo-Credential
		.PARAMETER Password
   			The password of the Powershell credential to convert. This would typically be 
			bound by property name when pipelineing credentials output by ConvertTo-Credential
		.PARAMETER Credential
   			The standard Powershell credential to convert to a PasswordVault credential.
			The conversion does NOT automatically store it within the vault.
		
		.EXAMPLE
			#Add a 100 test credentials to the PasswordVault, associated with an index numbered resource
			$added = 1..100 | Add-VaultCredential -UserName TestUser -Password (read-host -prompt Password -AsSecureString) -PassThrough

			#convert the PasswordVault credentials to standard Powershell credentials, and back again
			$added | ConvertTo-Credential | ConvertTo-VaultCredential

		.NOTES
			Author: Tim Bertalot
	#> 
	
	[CmdletBinding(  
		RemotingCapability		= "Powershell",
		SupportsShouldProcess   = $false,
		ConfirmImpact           = "Low", #chose low rather than none because it decodes the securestring password
		DefaultParameterSetName = ""
	)]
	
	[OutputType([Windows.Security.Credentials.PasswordCredential])]
	 
	param
	(
		[Parameter(
			ParameterSetName				= "PSCredential",
			HelpMessage						= "Enter the resource the credential applies to",
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[Parameter(
			ParameterSetName				= "VaultCredential",
			HelpMessage						= "Enter the resource the credential applies to",
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[String]
		$Resource,
		
		[Parameter(
			ParameterSetName				= "PSCredential",
			HelpMessage						= "Provide the Powershell credential to convert",
			Position						= 1,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.PSCredential]
		$Credential,

		[Parameter(
			ParameterSetName				= "VaultCredential",
			HelpMessage						= "Enter the user name(s) to add",
			Position						= 1,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[Alias("UN","Name","AccountName")]
		[String]
		$UserName,

		[Parameter(
			ParameterSetName				= "VaultCredential",
			HelpMessage						= "Enter the password for the user name",
			Position						= 2,
			Mandatory						= $true,
			ValueFromPipelineByPropertyName = $true
	  	)]
		[ValidateNotNullOrEmpty()]
		[SecureString]
		$Password
	)

	begin
	{
		$cmdName = (Get-PSCallStack)[0].Command
		Write-Debug "[$cmdName] Entering function"
	}
	
	process
	{
		try
		{
			if ($PSBoundParameters.Credential)
			{
				$UserName = $Credential.UserName
				$Password = $Credential.Password
			}
			#The PasswordVault credential constructor does not accept a securestring
			$insecurePassword = ConvertTo-PlainText $Password
			new-object Windows.Security.Credentials.PasswordCredential $Resource,$UserName,$insecurePassword
		}
		catch
		{
			Write-Error -ErrorRecord $_ 
		}
		finally
		{
			remove-Variable -Force -Confirm:$false -Name insecurePassword
		}
	}
	
	end
	{
		[gc]::Collect()
		Write-Debug "[$cmdName] Exiting function"
	}
}

function ConvertTo-PlainText 
{
	<#
		.SYNOPSIS
			Converts a secure string back to plain text. Use Sparingly as it will create in memory plain text
			versions of the string that persist for the lifetime of the Powershell process, thereby decreasing security
			http://www.leeholmes.com/blog/2006/09/07/securestrings-and-plain-text-in-Powershell/

		.PARAMETER SecureString
			The secure string to decode to plain text

		.Note
			Author: Tim Bertalot

			New improved version based on .Net code here:
			http://blogs.msdn.com/b/fpintos/archive/2009/06/12/how-to-properly-convert-securestring-to-string.aspx
	#>

	[CmdletBinding(  
		RemotingCapability		= "Powershell",
		SupportsShouldProcess   = $true,
		ConfirmImpact           = "Medium",
		DefaultParameterSetName = ""
	)]

	param
	(
   		[Parameter(
			Position						= 0,
			Mandatory						= $true,
			ValueFromPipeline				= $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[ValidateNotNull()]
		[Security.SecureString]
		$SecureString
	)
	
	process
	{
		if ($pscmdlet.ShouldProcess("Decode $($SecureString.Length) character secure string"))
		{

			[IntPtr] $unmanagedString = [IntPtr]::Zero;

			try
			{
				$unmanagedString = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($SecureString);
				[Runtime.InteropServices.Marshal]::PtrToStringUni($unmanagedString);
			}
			finally
			{
				[Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($unmanagedString);
			}
		}
	}
}