## [2026-02-17] - Az Aszinkron Kígyó Ébredése (v2.1-stable)

### Rendszerváltozások:
* **Hálózati Hurok**: Leválasztottuk a `pushEvent` hívást a fő `accept()` ciklusról a `std::thread::detach` segítségével.
* **Duguláselhárítás**: Eltávolítottuk a `window_with_time_or_count` operátort a `VenomBus`-ból, mert nagy terhelésnél (flood) blokkolta a reaktív láncot.
* **Típus-tisztítás**: Megszüntettük a `std::pair` használatát a pipeline-ban, kiküszöbölve az RxCpp belső összehasonlítási (operator==) hibáit.
* **Intelligens WC**: Bevezettük a dinamikus entrópiás küszöböt: `6.8 * (1.0 / (meta.loadFactor + 0.11))`.
* **Eredmény**: Stabil `netstat` (0 Recv-Q), azonnali erőforrás-felszabadítás és 100% hatékonyságú Null-Routing (WC).
