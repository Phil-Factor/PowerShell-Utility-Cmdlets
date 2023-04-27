<#
	.SYNOPSIS
		Gets a windows credential from the credential manager, or creates a credential if it doesn't yet exist
	
	.DESCRIPTION
        PowerShell provides a module to do this that has to be loaded separately, which is slightly odd of 
		it. To get around that, I've written a function that uses  a type written in C #.  (not by me, sadly).
		This type is a thin shim that uses advapi32, which provides advanced Windows API functions related to
		Windows, including access to the credential manager.  My part is to write the PowerShell to access the
		credentials, and query the user if the password can't be found within credential manager.
	.EXAMPLE
        #get or set the user philFactor for server 'Philf021'
		Get-WindowsCredential -User 'PhilFactor' -Server 'Philf021'

        #get or set the user philFactor for server 'Philf021' for sqlserver
		Get-WindowsCredential -User 'PhilFactor' -Server 'Philf021' -RDBMS='sqlserver'

        #get or set the user philFactor  saved with the token 'mysecret'
		Get-WindowsCredential -User 'PhilFactor' -token 'mysecret'

        #get the user philFactor  saved with the token 'mysecret'
        #add the userid when you set it
		Get-WindowsCredential -token 'mysecret'

	
	.PARAMETER User
		The user of the login.
	
	.PARAMETER Server
		The database or other server for which this is required.
	
	.PARAMETER RDBMS
		the RDBMS that is being served (usually the jdbc string). This is important only if you have one
		server that is hosting several relational systems.

	.PARAMETER Token
        if you wish to use a token rather than use lots of parameters that give away your userid
        you can use a token to save your credentials.

	.PARAMETER Conf
        You want the output in flyway.conf format.

	
	.NOTES
		Additional information about the function.
#>
function Get-WindowsCredential
{
	[CmdletBinding()]
	param
	(
		$User = $null,
		#the name of the user id

		$Server = $null,
		#the name of the server

		$RDBMS = $null,
		#the name of the RDBMS

		$Token = $null,
		#if you like to use a Token instead, to provide a password

		$Conf = $false #if you want a flyway-formatted password configuration
	)
	
	if ($User -eq $null -or $Server -eq $null)
	{
		if ($Token -eq $null)
		{ write-Error "You must provide at least a -User and -Server, or else use a token as parameter" }
	}
	
	
	# Loads SSH Password from Windows Credential Manager
	
	$CredManCsharp = @"
using System.Text;
using System;
using System.Runtime.InteropServices;
namespace CredManager {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CredentialMem
  {
    public int flags;
    public int type;
    public string targetName;
    public string comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME lastWritten;
    public int credentialBlobSize;
    public IntPtr credentialBlob;
    public int persist;
    public int attributeCount;
    public IntPtr credAttribute;
    public string targetAlias;
    public string userName;
  }
  public class Credential {
    public string target;
    public string username;
    public string password;
    public Credential(string target, string username, string password) {
      this.target = target;
      this.username = username;
      this.password = password;
    }
  }
  public class Util
  {
    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);
    //check if credential exists
    public static bool CredentialExists(string target) {
      IntPtr dummyCredentialPtr;
      return CredRead(target, 1, 0, out dummyCredentialPtr);
    }
    public static Credential GetUserCredential(string target)
    {
      CredentialMem credMem;
      IntPtr credPtr;
      if (CredRead(target, 1, 0, out credPtr))
      {
        credMem = Marshal.PtrToStructure<CredentialMem>(credPtr);
        byte[] passwordBytes = new byte[credMem.credentialBlobSize];
        Marshal.Copy(credMem.credentialBlob, passwordBytes, 0, credMem.credentialBlobSize);
        Credential cred = new Credential(credMem.targetName, credMem.userName, Encoding.Unicode.GetString(passwordBytes));
        return cred;
      } else {
        throw new Exception("Failed to retrieve credentials");
      }
    }
    [DllImport("Advapi32.dll", SetLastError = true, EntryPoint = "CredWriteW", CharSet = CharSet.Unicode)]
    private static extern bool CredWrite([In] ref CredentialMem userCredential, [In] int flags);
    public static void SetUserCredential(string target, string userName, string password)
    {
      CredentialMem userCredential = new CredentialMem();
      userCredential.targetName = target;
      userCredential.type = 1;
      userCredential.userName = userName;
      userCredential.attributeCount = 0;
      userCredential.persist = 3;
      byte[] bpassword = Encoding.Unicode.GetBytes(password);
      userCredential.credentialBlobSize = (int)bpassword.Length;
      userCredential.credentialBlob = Marshal.StringToCoTaskMemUni(password);
      if (!CredWrite(ref userCredential, 0))
      {
        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
      }
    }
  }
}
"@
	# thanks to Mavaddat Javid and others  for that code
	if (!([string]::IsNullOrEmpty($Token)))
	{
		$secret = $Token;
	}
	elseif ([string]::IsNullOrEmpty($rdbms))
	{ $secret = "$server-$user" }
	else
	{ $secret = "$rdbms-$server-$user" }
	
	$ItExists = $false #until proven otherwise
	try
	{
		$ItExists = [CredManager.Util]::CredentialExists($secret)
	}
	catch
	{
		Add-Type -TypeDefinition $CredManCsharp -Language CSharp
		try
		{
			$ItExists = [CredManager.Util]::CredentialExists($secret);
		}
		catch
		{
			write-warning "cannot get Credential for $Secret";
		}
	}
	
	if (!($ItExists))
	{
		if ([string]::IsNullOrEmpty($Token))
		{ $PromptMessage = "Please provide a user and password for token $Token "; }
		else
		{ $PromptMessage = "Please provide a password for user $user on server $Server" }
		
		Get-Credential -Message $PromptMessage -UserName $user |
		foreach {
			write-verbose "$secret, $($_.UserName), $($_.GetNetworkCredential().password)"
			[CredManager.Util]::SetUserCredential($secret, $_.UserName, $_.GetNetworkCredential().password)
		}
	}
	try
	{
		$OurCredential = [CredManager.Util]::GetUserCredential($secret);
	}
	catch
	{
		write-warning "cannot get Credential for $user to access $rdbms $server using token '$secret'";
	}
	if ($conf -eq $false) # just send the object so they can fill in userid and password
	{
		
		[pscustomobject]@{ 'user' = $OurCredential.Username; 'Password' = $OurCredential.password; }
	}
	else # just send the flyway.conf format for the credential
	{
		write-output "flyway.user=$($OurCredential.Username)`nflyway.password=$($OurCredential.password)`n"
	}
}