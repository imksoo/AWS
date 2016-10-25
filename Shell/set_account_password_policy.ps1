aws iam update-account-password-policy `
 --minimum-password-length 8 `
 --max-password-age 90 `
 --password-reuse-prevention 3 `
 --require-symbols `
 --require-numbers `
 --require-uppercase-characters `
 --require-lowercase-characters `
 --allow-users-to-change-password `
 --no-hard-expiry