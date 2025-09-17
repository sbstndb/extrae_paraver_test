#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ${0##*/} /path/to/samurai [build_dir]

- /path/to/samurai : chemin vers le dépôt Samurai local.
- build_dir        : nom du répertoire de build (défaut: build_extrae).

Le script s'assure de la présence d'Extrae via Spack, charge les modules
requis, configure CMake avec MPI et prépare extrae.xml + extrae_env.sh.
USAGE
}

abs_path() {
    python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 1
fi

if ! command -v spack >/dev/null 2>&1; then
    echo "Erreur: spack n'est pas disponible dans l'environnement." >&2
    exit 1
fi

SAMURAI_SRC=$(abs_path "$1")
if [[ ! -d $SAMURAI_SRC ]]; then
    echo "Erreur: $SAMURAI_SRC n'est pas un répertoire." >&2
    exit 1
fi

BUILD_NAME=${2:-build_extrae}
BUILD_DIR=$SAMURAI_SRC/$BUILD_NAME

if ! spack location -i extrae@4.2.3 ^openmpi >/dev/null 2>&1; then
    echo "Installation de extrae@4.2.3 ^openmpi via Spack..."
    spack install extrae@4.2.3 ^openmpi
fi

spack load samurai@0.26.1
spack load cli11/5
spack load extrae@4.2.3 ^openmpi

cmake -S "$SAMURAI_SRC" -B "$BUILD_DIR" -DWITH_MPI=ON

EXTRAE_HOME=$(spack location -i extrae@4.2.3 ^openmpi)
CONFIG_TEMPLATE=$EXTRAE_HOME/share/example/MPI/extrae.xml
TARGET_CONFIG=$BUILD_DIR/extrae.xml

if [[ -f $CONFIG_TEMPLATE && ! -f $TARGET_CONFIG ]]; then
    cp "$CONFIG_TEMPLATE" "$TARGET_CONFIG"
fi

ENV_FILE=$BUILD_DIR/extrae_env.sh
cat <<ENV >"$ENV_FILE"
# Généré par ${0##*/} le $(date --iso-8601=seconds)
export SAMURAI_SRC="$SAMURAI_SRC"
export SAMURAI_BUILD="$BUILD_DIR"
export EXTRAE_HOME="$EXTRAE_HOME"
export EXTRAE_CONFIG_FILE="$TARGET_CONFIG"
ENV

cat <<INFO
Configuration terminée.
- Build dir : $BUILD_DIR
- Config    : $TARGET_CONFIG
- Env file  : $ENV_FILE

Exécuter ensuite :
  cmake --build "$BUILD_DIR" --target finite-volume-advection-2d
INFO
