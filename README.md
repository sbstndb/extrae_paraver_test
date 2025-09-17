# Démo Extrae + Paraver

Cette démonstration montre comment instrumenter un mini code MPI avec Extrae, générer une trace Paraver et l’exploiter ensuite dans Paraver.

## Pré-requis
- Spack disponible dans l’environnement (déjà présent dans ce dépôt).
- Extrae installé avec un MPI supporté. Par exemple :
  ```bash
  spack install extrae@4.2.3 ^openmpi
  ```
- Certaines dépendances système peuvent être utiles (libarchive, libxml2, libunwind, papi…). Sur Ubuntu : `sudo apt-get install libarchive-dev libxml2-dev libunwind-dev libpapi-dev`.

## Compilation
```bash
spack load extrae@4.2.3 ^openmpi
cmake -S extrae_paraver -B extrae_paraver/build
cmake --build extrae_paraver/build
```

## Génération d’une trace
Deux possibilités :

### Variante automatisée
```bash
spack load extrae@4.2.3 ^openmpi
NP=4 extrae_paraver/scripts/run_demo.sh
```
- `NP` contrôle le nombre de rangs MPI (4 par défaut).
- OpenMPI 5 affiche parfois un message d’« abnormal termination » après la fin de l’application. C’est un faux positif connu avec Extrae ; la trace est bien produite.

### Variante pas à pas
```bash
spack load extrae@4.2.3 ^openmpi
cd extrae_paraver/build
export EXTRAE_CONFIG_FILE=$PWD/extrae.xml
export EXTRAE_ON=1
mpirun -np 4 ./extrae_demo || true         # ignorer le message final d’OpenMPI
mpi2prv -f trace.mpits -o demo_trace.prv -no-keep-mpits
```
Le second appel crée les fichiers `demo_trace.prv`, `demo_trace.pcf` et `demo_trace.row` tout en supprimant les fichiers MPIT intermédiaires.

## Visualisation
Copier (ou lier) les trois fichiers `demo_trace.*` sur un poste où Paraver/wxParaver est installé, puis ouvrir `demo_trace.prv` via l’interface graphique. Les événements utilisateur (type `Demo phases`) permettent de distinguer :
- `Compute stencil`
- `Global reduction`
- `Halo wait`

### Installer Paraver localement (optionnel)
Le dépôt inclut la procédure suivie pour compiler wxParaver 4.9.2 dans `~/paraver` :

1. Installer les dépendances : `sudo apt-get install libwxgtk3.2-dev libboost-all-dev`.
2. Télécharger les sources : `wget https://ftp.tools.bsc.es/wxparaver/wxparaver-4.9.2-src.tar.bz2` et extraire.
3. Configurer :
   ```bash
   cd wxparaver-4.9.2
   ./configure --prefix=$HOME/paraver \
     --with-boost=/usr --with-boost-libdir=/usr/lib/x86_64-linux-gnu \
     CXXFLAGS='-std=gnu++11'
   ```
4. Construire puis installer : `make -j8` puis `make install`.
5. Avant de lancer `wxparaver`, exporter :
   ```bash
   export PATH=$HOME/paraver/bin:$PATH
   export LD_LIBRARY_PATH=$HOME/paraver/lib/paraver-kernel:$LD_LIBRARY_PATH
   ```

## Nettoyage
```bash
rm -rf extrae_paraver/build
```
