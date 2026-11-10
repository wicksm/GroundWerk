# 4. Tests make their own Always Encrypted keys

Status: Accepted

## Context

Tax IDs are Always Encrypted columns. Each environment's column master key is a key in its own Key Vault, which only the workloads that read or write tax IDs can use, and the vaults become private in phase 3. PR builds run on Microsoft-hosted agents, which can't reach a private vault, yet PR tests have to read and write encrypted columns through the same SqlClient code the app uses.

## Decision

- Tests never use a real column master key. The test fixture, which runs SQL Server 2025 in a container, registers a key store provider named TEST_KEY_STORE whose master key is an RSA key made in the test process. It makes a random column encryption key for the run and passes both to the dacpac when it deploys, so a PR build needs no Key Vault, network path, service connection or secret.
- The dacpac's pre-deployment script creates each environment's column master key and column encryption key, if they don't exist yet, from three SQLCMD variables: CmkKeyStoreProvider, CmkKeyPath and CekEncryptedValue. Environments pass AZURE_KEY_VAULT and their key's path in Key Vault, and tests pass TEST_KEY_STORE. The variables have no defaults, so a publish that leaves one out fails.
- The model keeps placeholder keys only so its encrypted columns resolve, since a SQLCMD variable can't stand in for the binary ENCRYPTED_VALUE there (SQL46010). Every publish excludes the ColumnMasterKeys and ColumnEncryptionKeys object types, so the placeholders never deploy.

## Alternatives considered

- A dev Key Vault that PR builds reach through the pipeline's workload identity, which puts an Azure service connection within reach of every PR's code, and which a Microsoft-hosted agent can't reach once the vaults are private.
- The keys in the model, with a SQLCMD variable for each value, which the build refuses for the encrypted value.
- Leaving tax ID encryption until phase 3, when the vaults and the Managed DevOps Pool share the private network, which isn't needed, since the test key store costs nothing.

## Consequences

- PR tests run SqlClient's Always Encrypted path but not its Azure Key Vault provider, which only the deployed environments use.
- SqlClient allows one global key store registration in a process, so the Host registers its providers in one place at startup, which tests can replace with TEST_KEY_STORE.
- A publish without the two exclusions fails, since the pre-deployment script has already used the keys' names.
- The pre-deployment script only creates keys that are missing, so rotating a key is a runbook step, not a deploy.
- EF Core maps the tax ID with HasMaxLength(20). Without it, EF Core sends nvarchar(4000), which SQL Server refuses for the encrypted nvarchar(20) column with an operand type clash.
