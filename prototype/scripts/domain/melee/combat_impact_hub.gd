extends RefCounted
## The one signal impact and weapon sound consumers connect to (D-050).
## Obtain it through combat_impacts.gd `hub()`; never instantiate it yourself.

## record: see combat_impacts.gd (schema 1).
signal impact(record: Dictionary)
