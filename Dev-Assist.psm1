<#
    .SYNOPSIS
	    Retrieves the root cert from a website
	
	.PARAMETER Url
	    The Url of the website
	
	.EXAMPLE
	    $cert = Get-SiteRootCert -Url 'https://www.google.com'
#>
function Get-SiteRootCert
{
    [CmdletBinding()]
    param
	(
        [Parameter(Mandatory = $true)]
	    [string]
		$Url
	)
	
	$webRequest = [Net.WebRequest]::Create($Url)
    try
    {
        $webRequest.GetResponse().Dispose()
    }
    catch [System.Net.WebException]
    {
    }
    $cert = $webRequest.ServicePoint.Certificate
    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    $null = $chain.Build($cert)
    $chain.ChainElements |Foreach-Object {$_.Certificate} |Select-Object -Last 1
}

<#
    .SYNOPSIS
	    Adds a X509Certificate to git trusted root certs
	
	.PARAMETER Certificate
	    The certificate to add
	
	.PARAMETER CrtPath
	    The path to the crt file to update
	
	.EXAMPLE
	    $cert = Get-SiteRootCert -Url 'https://www.google.com'
	    Add-CertToGit -Certificate $cert
	
	.EXAMPLE
	    $cert = Get-SiteRootCert -Url 'https://www.google.com'
	    Add-CertToGit -Certificate $cert -CrtPath 'C:\Certs\MyCerts.crt'
#>
function Add-CertToGit
{
    [CmdletBinding()]
    param
	(
        [Parameter(Mandatory = $true)]
	    [X509Certificate]
		$Certificate,
		
        [Parameter()]
		[ValidateScript({Test-Path -Path $_ })]
        [ValidateScript({(Get-Item -Path $_).Extension -eq '.crt'})]
		[string]
		$CrtPath
	)

	if(Test-Path 'C:\Program Files\Git')
	{
		$x64 = $true
	}
	if(Test-Path 'C:\Program Files (x86)\Git')
	{
		$x32 = $true
	}

	if( -not $x32 -and -not $x64)
	{
		throw 'This command requires Git'
	}
	
	if($CrtPath)
	{
	    $crtInfo = Get-Item $CrtPath
	}
	else
	{
        if($x64)
        {
            $crtInfo = Copy-Item 'C:\Program Files\Git\mingw64\ssl\certs\ca-bundle.crt' -Destination $Env:USERPROFILE -PassThru
        }
        elseif($x32)
        {
            $crtInfo = Copy-Item 'C:\Program Files (x86)\Git\mingw32\ssl\certs\ca-bundle.crt' -Destination $Env:USERPROFILE -PassThru
        }       
	}
    $certBegin = '-----BEGIN CERTIFICATE-----'
	$rootBase64 = [convert]::ToBase64String($Certificate.RawData)
    $certEnd = '-----END CERTIFICATE-----'
    Add-Content -Path $crtInfo.FullName -Value "`n$certBegin`n$rootBase64`n$certEnd" -NoNewline
    git config --global http.sslCAInfo $crtInfo.FullName
}

<#
    .SYNOPSIS
	    Ensures that environment Path variables are unique and properly formatted
	
	.EXAMPLE
	    $null = Optimize-PathVariables
#>
function Optimize-PathVariables
{
	# System
	$vars = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
	$pathSplit = $vars -split ';' | Foreach-Object {$_.trim()} | Where-Object {$_} | Sort-Object -Unique
	[Environment]::SetEnvironmentVariable('Path', $pathSplit -join ';', [System.EnvironmentVariableTarget]::Machine)

	# User	
	$vars = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
	$pathSplit = $vars -split ';' | Foreach-Object {$_.trim()} | Where-Object {$_} | Sort-Object -Unique
	[Environment]::SetEnvironmentVariable('Path', $pathSplit -join ';', [System.EnvironmentVariableTarget]::User)

	# Session
	$pathVar = $env:Path
	$pathSplit = $pathVar -split ';' | Foreach-Object {$_.trim()} | Where-Object {$_} | Sort-Object -Unique
	$env:Path = $pathSplit -join ';'
}