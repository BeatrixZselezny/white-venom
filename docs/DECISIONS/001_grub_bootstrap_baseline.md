# Döntés #0001: GRUB environment baseline biztosítása a bootstrap elején
Dátum: 2025-11-30
Állapot: Accepted

## Indoklás
A hw_vuln / kernelopts injection működéséhez szükséges a grub-editenv
vagy grub2-editenv megléte. Minimal telepítéseknél ezek hiányozhatnak.
Ez megakasztaná a teljes hardening pipeline-t a legelső fázisban.

## Döntés
A 00_install.sh elejére bekerült egy robust detect + auto-install mechanizmus,
amely telepíti a szükséges grub-common és grub2-common csomagokat.

## Hatás
- determinisztikus bootstrap flow
- early hw_vuln mitigation garantált
- orchestrator stabil működés

## Alternatívák
- kizárólag orchestrator fallback check (megtartva másodlagos védelemként)
