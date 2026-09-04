using Aqua

#  Extras (Conda, PyCall, Documenter, ...) are test-only, no compat needed
Aqua.test_all(CfGRIB; deps_compat=(; check_extras=false))
