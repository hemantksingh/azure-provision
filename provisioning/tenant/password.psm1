function New-SecureRandomPassword(
	[Parameter(mandatory = $true)][string]$characterSets, 
	[Parameter(mandatory = $true)][int]$length) {
		$pass = $(New-RandomPassword -Size $length -CharSets $characterSets)
		return @{
			plainText = $pass
			secureString = (ConvertTo-SecureString  $pass -AsPlainText -Force)
		}
	}

function New-RandomPassword
{
	param (
		[Int]$Size = 12,
		[Char[]]$CharSets = "ULULNS",
		[Char[]]$Exclude
	)
		
	
	$Chars = @()

	If (!$TokenSets)
	{
		$Global:TokenSets = @{
			U   = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ' # Upper case
			L   = [Char[]]'abcdefghijklmnopqrstuvwxyz' # Lower case
			N   = [Char[]]'0123456789' # Numerals
			S   = [Char[]]'!*+.:_~' # Symbols
			Q   = [Char[]]'!*+._~' # SQL Symbols
		}
    }
    
	$CharSets | ForEach-Object {
		$Tokens = $TokenSets."$_" | ForEach-Object { If ($Exclude -cNotContains $_) { $_ } }
		If ($Tokens)
		{
			$TokensSet += $Tokens
			If ($_ -cle [Char]"Z") { $Chars += $Tokens | Get-Random } # Character sets defined in upper case are mandatory
		}
	}
	While ($Chars.Count -lt $Size) { $Chars += $TokensSet | Get-Random }
	($Chars | Sort-Object { Get-Random }) -Join "" # Mix the (mandatory) characters and output string
}

Export-ModuleMember "*"