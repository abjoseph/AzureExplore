Function Resolve-Error ($ErrorRecord=$Error[0])
{
   $ErrorRecord | Format-List * -Force | Out-String | Write-Output
   $ErrorRecord.InvocationInfo |Format-List * | Out-String | Write-Output
   $Exception = $ErrorRecord.Exception
   for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
   {   “$i” * 80
       $Exception |Format-List * -Force | Out-String | Write-Output
   }
}

$VerbosePreference = "Continue"

$SMOAssemblies = "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.SmoExtended", "Microsoft.SqlServer.ConnectionInfo"

$SmoAssemblyPath = "C:\Smo\150\net45\" #Source --> https://www.nuget.org/packages/Microsoft.SqlServer.SqlManagementObjects/150.18118.0

If(Test-Path $SmoAssemblyPath)
{ 
    $SMOAssemblies | %{ $SmoAssemblyPath + $_ + ".dll" } | %{ [System.Reflection.Assembly]::LoadFrom($_) } | %{ Write-Host "Loaded:"; Select-Object -InputObject $_ FullName, Location } | %{ Format-List -InputObject $_ | Out-String | Write-Host }
}
Else
{
    $SMOAssemblies | %{[Reflection.Assembly]::LoadWithPartialName($_)} | %{Write-Host "Loaded:"; Select-Object -InputObject $_ FullName, Location | Format-List}
}

Function Get-SQLServer {
    [CmdletBinding()]  
    Param(  
        [string]$ConnectionString
    )  
    process
    {
        try 
        {
            Write-Verbose "Opening connection..."
            $sqlConnection = new-object System.Data.SqlClient.SqlConnection($connectionString)
            $sqlConnection.AccessToken = "<AccessToken>" # **Comment out this line when using/switching to Active Directory Password based authentication.**
            $conn = new-object Microsoft.SqlServer.Management.Common.ServerConnection($sqlConnection)
            #$conn.AccessToken = "<Unknown>" -- **No documentation of how to populate this property or what type to create to assign to it.**
            $conn | select -Property * -ExcludeProperty Password, ConnectionString | Out-ObjectToVerbose -Label "[Connection] "
            $server = new-object Microsoft.SqlServer.Management.SMO.Server($conn)
            $sqlConnection | select -Property * -ExcludeProperty Password, ConnectionString | Out-ObjectToVerbose -Label "[SQLConnection] "
        }
        catch
        {
            $base = $_.Exception.GetBaseException()
            Write-Error -Message "Unable to connect" -Category OpenError -CategoryTargetName "Server" -CategoryReason $base.Message -CategoryTargetType $ServerName -CategoryActivity "Open Error"
            throw
        }
        $server | select -Property $VerboseSQLServer | Out-ObjectToVerbose -Label "[Server] " #
        return $server
    }
}

Function Out-ObjectToVerbose
{
    [CmdletBinding()]  
    Param(  
        [Parameter(ValueFromPipeline)]
        [PSObject]$Obj,
        [string]$Label
	)
    process
    {
        $Obj.psobject.properties | %{ Write-Verbose "$($Label)$($_.Name): $(Get-Value $_)" } 
        Write-Verbose "--- End of Object ---"
    }
}

Function Get-Value ($object)
{
    Try { if($object.Value) { return "$($object.Value)" }else { return '$null' } } Catch { return $_.Exception.Message }
} 

Function Get-Databases {
    [CmdletBinding()]  
    Param(  
        [Parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Server]$Server,
        [string[]]$DBNames
    )
    begin
    {
        if (($DBNames.Count -eq 1) -and $DBNames[0].Contains(',')) {$DBNames = $DBNames -split ',' | %{$_.Trim()}}
    }
    process
    {
        try 
        {
            $Server.Databases.Where({$_.Name -in $DBNames})
        }
        catch
        {
            $host.ui.WriteErrorLine($_.Exception.GetBaseException().Message)
            throw
        }        
    }
}

Try {

    #$Server = Get-SQLServer -ConnectionString 'Data Source=<Azure-SQL-Datbase>.database.windows.net;Initial Catalog=master;User ID=john.doe@microsoft.com;Password=ABC123;Connect Timeout=30;Authentication="Active Directory Password"'

    $Server = Get-SQLServer -ConnectionString "Data Source=<Azure-SQL-Datbase>.database.windows.net; Initial Catalog=master"

    $Database = $Server | Get-Databases -DBNames @("<Azure-SQL-Datbase>") | select -First 1 

    $dbUser = new-object Microsoft.SqlServer.Management.Smo.User($Database, "john.doe@microsoft.com");

    $dbUser.UserType = 4 

    $dbUser.Script() #Produces the following which is the correct syntax for creating Azure AD based users "CREATE USER [john.doe@microsoft.com] FROM  EXTERNAL PROVIDER"

    $dbUser.Create()
}
Catch {

    $errorDetails = Resolve-Error
    $host.ui.WriteErrorLine("Printing Error Details: $($errorDetails)")
}
