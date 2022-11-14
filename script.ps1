# I'm using Azure CLI in this example:
$aksName = "aks-cluster-test-we-01"
$aksResourceGroup = "rg-cluster-test-we"
$ficid = "fic-batman-test-we-01"
$idName = "id-batman-test-we-01"
$kvResourceGroup = "rg-secrets-test-we"
$kvName = "kv-mysecrets-test-we-01"
$location = "westeurope"
$mySecretName = "mySecret"
$mySecretValue = "superSecret"
$namespace = "hero"
$serviceAccountName = "workload-identity-batman"

# Create resource group for the AKS:
az group create --name $aksResourceGroup --location $location

# Create AKS:
az aks create --resource-group $aksResourceGroup --name $aksName --node-count 1 --enable-oidc-issuer --enable-addons azure-keyvault-secrets-provider --enable-workload-identity --network-plugin azure --kubernetes-version 1.22 --location $location

# Create resource group for the Key Vault:
az group create --name $kvResourceGroup --location $location

# Create Key Vault:
az keyvault create --name $kvName --resource-group $kvResourceGroup --location $location 

# Create secret:
az keyvault secret set --vault-name $kvName --name $mySecretName --value $mySecretValue

# Create Azure Managed Identity:
az identity create -g $aksResourceGroup -n $idName

# Get Client Id for the Managed Identity:
$idClientId = (az identity show --name $idName --resource-group $aksResourceGroup| ConvertFrom-Json).clientId

# Give User Managed Identity rights to get secret from the Key Vault:
az keyvault set-policy -n $kvName --secret-permissions get --spn $idClientId

# Get the OIDC Issuer URL:
$aks_oidc_issuer = "$(az aks show -n $aksName -g $aksResourceGroup --query "oidcIssuerProfile.issuerUrl" -otsv)"

# Establish federated identity credential:
az identity federated-credential create --name $ficid --identity-name $idName --resource-group $aksResourceGroup --issuer $aks_oidc_issuer --subject system:serviceaccount:${namespace}:${serviceAccountName}

# Get tenant id:
$tenantId = $(az aks show --name $aksName --resource-group $aksResourceGroup --query "identity.tenantId" --output tsv)