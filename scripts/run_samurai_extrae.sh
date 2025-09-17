#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ${0##*/} [options] -- command [args...]

Options:
  -s, --samurai-root PATH   Chemin vers les sources Samurai (sinon depuis env file)
  -b, --build NAME           Nom du répertoire de build (défaut: build_extrae)
  -e, --env FILE             Fichier d'environnement généré (extrae_env.sh)
  -h, --help                 Affiche cette aide

Le script charge les dépendances Spack, prépare Extrae et exécute la commande
fournie (ex: "mpirun -np 4 ./demo --timers").
USAGE
}

abs_path() {
    python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

SAMURAI_ROOT=""
BUILD_NAME="build_extrae"
ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--samurai-root)
            [[ $# -ge 2 ]] || { echo "Option $1 requiert un argument" >&2; exit 1; }
            SAMURAI_ROOT=$(abs_path "$2")
            shift 2
            ;;
        -b|--build)
            [[ $# -ge 2 ]] || { echo "Option $1 requiert un argument" >&2; exit 1; }
            BUILD_NAME="$2"
            shift 2
            ;;
        -e|--env)
            [[ $# -ge 2 ]] || { echo "Option $1 requiert un argument" >&2; exit 1; }
            ENV_FILE=$(abs_path "$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

if [[ -z $ENV_FILE ]]; then
    if [[ -n $SAMURAI_ROOT ]]; then
        ENV_FILE="$SAMURAI_ROOT/$BUILD_NAME/extrae_env.sh"
    elif [[ -f ./extrae_env.sh ]]; then
        ENV_FILE=$(abs_path ./extrae_env.sh)
    elif [[ -f ../extrae_env.sh ]]; then
        ENV_FILE=$(abs_path ../extrae_env.sh)
    else
        echo "Erreur: impossible de localiser extrae_env.sh (utiliser --env ou --samurai-root)." >&2
        exit 1
    fi
fi

if [[ ! -f $ENV_FILE ]]; then
    echo "Erreur: fichier d'environnement introuvable: $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

if [[ -z ${SAMURAI_BUILD:-} ]]; then
    if [[ -n $SAMURAI_ROOT ]]; then
        SAMURAI_BUILD="$SAMURAI_ROOT/$BUILD_NAME"
    else
        echo "Erreur: variable SAMURAI_BUILD absente dans $ENV_FILE." >&2
        exit 1
    fi
fi

if [[ ! -d $SAMURAI_BUILD ]]; then
    echo "Erreur: répertoire de build introuvable: $SAMURAI_BUILD" >&2
    exit 1
fi

if [[ -z ${EXTRAE_HOME:-} ]]; then
    echo "Erreur: EXTRAE_HOME non défini (vérifier $ENV_FILE)." >&2
    exit 1
fi

if ! command -v spack >/dev/null 2>&1; then
    echo "Erreur: spack n'est pas disponible dans l'environnement." >&2
    exit 1
fi

spack load samurai@0.26.1
spack load cli11/5
spack load extrae@4.2.3 ^openmpi

source "$EXTRAE_HOME/etc/extrae.sh"

export EXTRAE_CONFIG_FILE=${EXTRAE_CONFIG_FILE:-$SAMURAI_BUILD/extrae.xml}
export EXTRAE_ON=1
export LD_PRELOAD="${EXTRAE_HOME}/lib/libmpitrace.so${LD_PRELOAD:+:$LD_PRELOAD}"

COMMAND=("$@")
exec "${COMMAND[@]}"
