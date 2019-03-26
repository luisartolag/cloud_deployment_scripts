﻿#
# Script downloaded from https://activedirectorypro.com/create-bulk-users-active-directory/
# on 2019.03.22. Modified for Teradici use.
#
Write-Output "================================================================"
Write-Output "Creating new AD Domain Users from CSV file..."
Write-Output "================================================================"

#Store the data from ADUsers.csv in the $ADUsers variable
$ADUsers = Import-csv ${csv_file}

#Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers)
{
    #Read user data from each field in each row and assign the data to a variable as below

    $Username 	= $User.username
    $Password 	= $User.password
    $Firstname 	= $User.firstname
    $Lastname 	= $User.lastname
    $OU 		= $User.ou #This field refers to the OU the user account is to be created in
    $email      = $User.email
    $streetaddress = $User.streetaddress
    $city       = $User.city
    $zipcode    = $User.zipcode
    $state      = $User.state
    $country    = $User.country
    $telephone  = $User.telephone
    $jobtitle   = $User.jobtitle
    $company    = $User.company
    $department = $User.department
    $Password = $User.Password


    #Check to see if the user already exists in AD
    if (Get-ADUser -F {SamAccountName -eq $Username})
    {
        #If user does exist, give a warning
        Write-Warning "A user account with username $Username already exist in Active Directory."
    }
    else
    {
        #User does not exist then proceed to create the new user account

        #Account will be created in the OU provided by the $OU variable read from the CSV file
        New-ADUser `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@${domain_name}" `
            -Name "$Firstname $Lastname" `
            -GivenName $Firstname `
            -Surname $Lastname `
            -Enabled $True `
            -DisplayName "$Lastname, $Firstname" `
            -City $city `
            -Company $company `
            -State $state `
            -StreetAddress $streetaddress `
            -OfficePhone $telephone `
            -EmailAddress $email `
            -Title $jobtitle `
            -Department $department `
            -AccountPassword (convertto-securestring $Password -AsPlainText -Force) -ChangePasswordAtLogon $False
    }
}