#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
NP=${NP:-4}

if [[ -z "${EXTRAE_HOME:-}" ]]; then
  echo "EXTRAE_HOME n'est pas défini. Charge d'abord Extrae (ex: 'spack load extrae@4.2.3 ^openmpi')." >&2
  exit 1
fi

cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" >/dev/null
cmake --build "${BUILD_DIR}" >/dev/null

pushd "${BUILD_DIR}" >/dev/null
export EXTRAE_CONFIG_FILE="${BUILD_DIR}/extrae.xml"
export EXTRAE_ON=1

rm -rf set-0 trace.mpits trace.spawn demo_trace.prv demo_trace.pcf demo_trace.row
status=0
if ! mpirun -np "${NP}" ./extrae_demo; then
  status=$?
  echo "mpirun a renvoyé ${status}. Avec OpenMPI 5, Extrae termine parfois avec un faux positif. On continue." >&2
fi

if [[ ! -f trace.mpits ]]; then
  echo "Échec: trace.mpits introuvable." >&2
  exit 1
fi

mpi2prv -f trace.mpits -o demo_trace.prv -no-keep-mpits >/dev/null

popd >/dev/null

echo "Trace Paraver générée : ${BUILD_DIR}/demo_trace.prv (+ .pcf/.row)"
