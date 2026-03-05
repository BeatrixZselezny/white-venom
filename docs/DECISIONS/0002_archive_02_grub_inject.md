# Döntés #0002: 02_grub_inject.sh archiválása
Dátum: 2025-11-30
Állapot: Accepted

## Indoklás
A GRUB/kernelopts manipuláció és CPU vulnerability injection centralizálódott
az orchestrator early-phase részébe. Így a külön modul fenntartása redundáns,
driftforrást jelent és késleltetné a mitigációt.

## Döntés
A 02_grub_inject.sh átkerült a `parking/` könyvtárba.
A modulfa teljes újraszámozása megtörtént (venom_modtree_renumber.sh).

## Hatás
- tisztább modulfa
- a legkritikusabb mitigation korai fázisban történik
- a hardening pipeline konzisztensebb

## Alternatívák
- modul megtartása külön állományként (elvetve)
