#!/bin/bash

vault auth -method=ldap -address=https://ewe-vault.test.expedia.com username="snicoud" \
	&& cp -f ~snicoud/.vault-token /secret/vault_token


