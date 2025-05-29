export LM_LICENSE_FILE="5052@localhost"
export MGLS_LICENSE_FILE="5052@localhost"

export ALTERA_ROOT="/opt/altera/24.1std"

export QUARTUS_ROOTDIR="${ALTERA_ROOT}/quartus"
export QUESTASIM_ROOT="${ALTERA_ROOT}/questa_fe"
export RISCFREE_ROOT="${ALTERA_ROOT}/riscfree"

export PATH="${ALTERA_ROOT}/nios2eds/bin:${ALTERA_ROOT}/niosv/bin:${QUARTUS_ROOTDIR}/bin:${QUESTASIM_ROOT}/bin:${RISCFREE_ROOT}/RiscFree:${RISCFREE_ROOT}/toolchain/riscv32-unknown-elf/bin${PATH:+:${PATH}}"
