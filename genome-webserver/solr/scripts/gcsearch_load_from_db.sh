#!/bin/bash

set -o errexit   # exit if any command fails
set -o pipefail  # fail if any command in a pipe fails
set -o nounset   # fail if an env var is used but unset


bsub -u jlolofie@genome.wustl.edu -q apipe perl /gsc/scripts/bin/gcsearch_load_from_db --add processing_profile,model,model_group --lock 1
bsub -u jlolofie@genome.wustl.edu -q apipe perl /gsc/scripts/bin/gcsearch_load_from_db --add individual,flowcell,sample,population_group --lock 2
bsub -u jlolofie@genome.wustl.edu -q apipe perl /gsc/scripts/bin/gcsearch_load_from_db --add taxon,libary,disk_group,disk_volume,work_order --lock 3





