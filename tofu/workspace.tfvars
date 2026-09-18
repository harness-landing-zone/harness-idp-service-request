# Settings every IaCM workspace run of this root shares. The pipeline attaches
# this file to the workspace. It is not loaded by a local run, because only
# *.auto.tfvars files are picked up automatically.

# In the workspace the config files already come from Git, so the run only
# reconciles Harness with them and writes nothing to the runner's disk.
write_files = false
