aws iam get-account-password-policy | ConvertFrom-Json | Select-Object -ExpandProperty PasswordPolicy
