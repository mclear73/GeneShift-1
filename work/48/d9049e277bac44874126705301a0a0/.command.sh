#!/bin/bash -ue
module load anaconda3/5.1.0-gcc 
source activate GeneShift_env
python /home/mclear73/GeneShift/bin/InputPrep.py            -i Test_exp_rep.csv             -o Test
