using './main.bicep'

param location = 'centralindia'
param myPublicIp = '0.0.0.0' // Replace with your actual public IP (https://ifconfig.me)
param vmAdminUsername = 'saurav'
param vmAdminPassword = 'REPLACE_WITH_STRONG_PASSWORD' // Use: az deployment group create --parameters vmAdminPassword=<value>
param projectName = 'portfolio'
