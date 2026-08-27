class_name BuyMode
extends RefCounted
## Mode d'achat partagé entre BuyModeSelector (UI) et GeneratorRow (calcul du
## coût) : x1, x10, ou "max abordable" (recalculé à chaque refresh depuis l'or
## courant, cf. EconomyFormulas.max_affordable).

enum { ONE, TEN, MAX }
