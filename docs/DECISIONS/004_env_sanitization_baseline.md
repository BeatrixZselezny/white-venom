# White Venom – Environment Sanitization Baseline (ID: 004)

## Summary
A bootstrap rootként fut, ezért **a user-space environment öröklődése
elfogadhatatlan kockázat**. A White Venom első lépése egy teljes env-sterilizáció.

## Attack Classes Blocked
- LD_PRELOAD-based root privilege escalation
- LD_LIBRARY_PATH poisoning
- BASH_FUNC exported function override (Shellshock derivatives)
- PATH poisoning (fake binaries → root execution)
- IFS manipulation (path traversal + command splitting)
- Python/Ruby/Perl/Node/Go loadpath injection
- Git config hijacking
- Locale format-string exploitation

## Implemented Controls
- `PATH="/usr/sbin:/usr/bin:/sbin:/bin"`
- `IFS` reset
- All `LD_*` vars unset
- Python/Ruby/Perl/Go/Node vars unset
- Remove all `BASH_FUNC_*%%`
- `LANG=C`, `LC_ALL=C`
- Unset SHELLOPTS
- Clean, predictable, reproducible ambient environment

## Execution Timing
Env-sterilizáció **a legelső parancsok között**, közvetlenül:
