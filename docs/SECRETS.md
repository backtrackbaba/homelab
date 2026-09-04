# Secret management

The repository uses **SOPS + age**:

1. Install tools: `make install-tools`.
2. Create a local age identity: `age-keygen -o ~/.config/sops/age/keys.txt`.
3. Copy the printed public key into `.sops.yaml` based on `.sops.yaml.example`.
4. Create the encrypted file directly:

   ```bash
   cp secrets.example.env /tmp/home-server-secrets.env
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops --encrypt /tmp/home-server-secrets.env > secrets.enc.env
   rm /tmp/home-server-secrets.env
   ```

5. Edit later with:

   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets.enc.env
   ```

`./scripts/decrypt-secrets.sh` writes decrypted values into `.runtime/`, which is ignored by Git and mode `0700`. Compose file secrets are mounted only into PostgreSQL and Redis. Applications that require environment variables consume `.runtime/secrets.env`.

Back up the age private key separately. Losing it means losing access to the encrypted secrets.


## Make targets

Use `make age-key`, `make secrets-create`, `make secrets-edit`, and `make secrets-decrypt` for the normal workflow.
