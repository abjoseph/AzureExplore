using Microsoft.Azure.Services.AppAuthentication;
using System;
using System.Data.SqlClient;

static class Program
{
    static void Main()
    {
        SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder();
        builder["Data Source"] = "<Azure-SQL-Datbase>.database.windows.net";
        builder["Initial Catalog"] = "master";
        //builder["Authentication"] = SqlAuthenticationMethod.ActiveDirectoryPassword;
        builder["Connect Timeout"] = 30;
        //builder.Password = "ABC123";
        //builder.UserID = "john.doe@microsoft.com";

        var cs = builder.ConnectionString;
        Console.WriteLine(cs);
        using (SqlConnection connection = new SqlConnection(builder.ConnectionString))
        {
            try
            {
                var accessToken = (new AzureServiceTokenProvider()).GetAccessTokenAsync("https://database.windows.net/").Result;
                connection.AccessToken = accessToken;

                connection.Open();
                using (SqlCommand cmd = new SqlCommand(@"SELECT SUSER_SNAME()", connection))
                {
                    Console.WriteLine("You have successfully logged on as: " + (string)cmd.ExecuteScalar());
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
            }
        }
        Console.WriteLine("Please press any key to stop");
        Console.ReadKey();
    }
}
