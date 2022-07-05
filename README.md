# GeneShift

Note: this repo has been forked and edited to run on a different cluster than was originally designed. No substantial changes have been made to the code. Bash and PBS scripts were simply changed to so they could run on a different cluster.

This workflow is designed to detect pattern change of time-series gene expression data. 
![Image of GeneShift](https://github.com/yueyaog/GeneShift/blob/master/Auxiliary/GeneShift_repo.png)

## Workflow Summary
 GeneShift workflow performs the following tasks:
  1. Generate input dataset
  2. Compute initial clustering using [soft-DTW-KMeans](https://arxiv.org/abs/1703.01541)
  3. Compute fine clustering with [DP_GP_cluster](https://github.com/PrincetonUniversity/DP_GP_cluster/tree/master/DP_GP)
  4. Determine the optial number of clusters
  5. Using deep learning model(RNN LSTM) to test the robusticity of clustering 
  6. Post-clustering analysis (replicate sorting) 
  
## Installation
All of GeneShift dependencies can be installed through Anaconda3. The following installation commands are specified to create Anaconda environments using Clemson's Palmetto cluster. But the dependencies can be easily install to any other HPC system.

Two anaconda environments need to created for GeneShift
```
conda create -n GeneShift_env python=3.6 matplotlib numpy pandas scikit-learn 

# tslearn needs to be installed separately.
source activate GeneShift_env

conda install -c conda-forge tslearn

source deactivate

conda create -n DPGP_env python=2.7 GPy pandas numpy scipy matplotlib
```
Once the two anaconda environments have been created, simply clone GeneShift repository to use GeneShift
```
module load git/2.27.0-gcc/8.3.1

git clone https://github.com/yueyaog/GeneShift.git
```

## Input Data
GeneShift takes ```*_exp_rep.csv``` of the format:
|               | time_1 | time_2 | time_3 | ... | time_n |
|---------------|--------|--------|--------|-----|--------|
| A_gene_1_rep1 |  6.128 |  3.564 |  1.232 | ... |  4.217 |
| A_gene_1_rep2 |  5.940 |  2.817 |  0.715 | ... |  3.829 |
| A_gene_1_rep3 |  6.591 |  3.902 |  1.594 | ... |  4.336 |
| B_gene_1_rep1 |  5.412 |  2.781 |  0.790 | ... |  8.772 |
| B_gene_1_rep2 |  6.195 |  2.066 |  0.815 | ... |  8.891 |
| B_gene_1_rep3 |  5.836 |  3.097 |  0.836 | ... |  9.096 |
| A_gene_2_rep1 |  0.734 |  1.236 |  4.849 | ... |  6.110 |
|      ...      |   ...  |   ...  |   ...  | ... |   ...  |
| B_gene_n_rep3 |  7.889 |  13.206|  11.192| ... |  9.761 |

The first row is a header containing the time points, and the first column is an index containing condition, geneID, and rep. You can replace A and B with specific conditions' names. However, you can't change the replicate names. They have to be 'rep1', 'rep2', 'rep3'. Entries are separated by comma. Quantile normalization and log<sub>2</sub>(x+1) transformation need to applied before you input ```*_exp_rep.csv``` to GeneShift workflow. GeneShift contains a test gene expression matrix for testing purposes. 

## Execute the Workflow

### Running GeneShift Nextflow Pipeline
Now, you can run GeneShift as a Nextflow pipeline. It is way easier than executing all the shell scripts one by one and 'babysitting' the submission processes for each task. Instead, you can complete the entire workflow with a single command. The following command will run the example data ```Test_exp_rep.csv``` with K range from 5 to 40. This command is specific to the PBS scheduler on the Clemson palmetto cluster. It can generalize to any HPC system by adding a few modifications in ```nextflow.config```. Although you don't need to run the python script directly, you may want to refer to the following documentation to familiarize yourself with the details of the GeneShift workflow.


```
nextflow run main.nf -profile palmetto  --gem_file Test_exp_rep.csv --data_prefix Test --Kmin 5 --Kmax 40  --StepSize 5
```

NOTE: Kmax will not included in the final range list because of Groovy syntax. If your Kmin = 5, Kmax = 20, StepSize =5, your k range list will be [5,10,15]


### Running GeneShift Python Script Directly

First, user need to execute ```initiate.sh``` to make sure the output from each step will be stored properly.
```
$ ./initiate.sh
```

### Prepare Input
To avoid noises in gene expression data clustering, input data will be separated into ```OFF_exp.csv``` and ```OFFremoved_exp.csv```. Clustering will only be performed on ```OFFremoved_exp.csv``` . ```OFF_exp.csv``` will be analyzed in post-clustering analysis.
```
$ cd 00-DataPrep/
$ ./00-DataPrep.sh
```

### Initial Clustering (DTW-KMeans)
[Soft-DTW-KMeans](https://arxiv.org/abs/1703.01541) with a range of K values will be appied to the ```OFFremoved_exp.csv```. Provide the values of K<sub>min</sub>, K<sub>max</sub>, and step size to set up a range of K values. 
```
$ cd 01-DTWKMeans/
$ ./01-DTWKMeans.sh $Kmin $Kmax $StepSize
```

### Fine Clustering (DP_GP_Cluster)
The initial clustering results will be fine clustered by [Dirichlet process Gaussian process model](https://github.com/PrincetonUniversity/DP_GP_cluster/tree/master/DP_GP).
```
$ cd 02-DP_GP/
$ qsub dpgp_prep.pbs
$ ./02-DP.sh
```

### Choose Optimal K (ch index, db index, silhouette coefficient)
Before determine the optimal K from a range of k values we tested, the clustering results (from 01-DTWKMeans and 02-DP-GP) need to be compiled.
```
$ cd 03-ChooseK
$ ./03-1-ClusterSum.sh $Kmin $Kmax $StepSize
```
Once the clustering results are being summarized into several csv files, three analysis will be used to choose an optimal K value. [Calinski harabasz index](https://doi.org/10.1080/03610927408827101), [silhouette score](https://doi.org/10.1016/0377-0427(87)90125-7), [davies bouldin index](https://doi.org/10.1109/TPAMI.1979.4766909) will be calculated of various K values. The performance of different K values will be visualized in the output plot. 
- Davies bouldin index closer to zero indicate a better partition.
- Calinski harabasz index is higher when clusters are dense and well separated, which relates to a standard concept of a cluster.
- Silhouette score is bounded between -1 for incorrect clustering and +1 for highly dense clustering. Scores around zero indicate overlapping clusters.

To choose the optimal K value
```
$ ./03-2-ChooseK.sh
```
For example, we choosed ```DTW_n_cluster```=37 based on the results in the following figure. Calinski harabasz index is the highest among all cluster size, David bouldin index is relatively lower compare with most others, silhouette score is relatively higher compare with most others. 

![Image of PERFS](https://github.com/yueyaog/GeneShift/blob/master/Auxiliary/DTW-DPGP_diffKs_PERFs.png)

If you executing GeneShift nextflow pipeline, the updated script can compute the optimal K value based on the rank of the results from the three statistical tests. You can bypass the setting by modify ```Output/OptimalK/Optimal_K_value.txt```. And resume the nextflow pipeline by the following command. 

```
nextflow run main.nf -profile palmetto -resume
```


### Post-clustering analysis (replicate sorting)

To conduct post-clustering analysis, execute 04-1ClusterShift script and provide the optimal K value as argument:
```
$ cd 04-DetectShift 
$ ./04-1ClusterShift.sh $OPTIMAL_K
```
To visualize the results of Cluster Shift, execute the following command. 
```
$ ./04-2ClusterShift_Visu.sh $OPTIMAL_K
```
GeneShift offers two ways of visualizing the output: box-point plot and basic line plot. You can observe the expression of replicates better in basic line plot than box-point plot.  

![Image of BoxLine Plot](https://github.com/yueyaog/GeneShift/blob/master/Auxiliary/BxPt_FPKM_TrajecotrySet_A_DTW-K37-017-DPGP001_B_DTW-K37-017-DPGP001.png)
![Image of BasicLine Plot](https://github.com/yueyaog/GeneShift/blob/master/Auxiliary/LnPt_FPKM_TrajecotrySet_A_DTW-K37-017-DPGP001_B_DTW-K37-017-DPGP001.png)
## Classification

__Overview:__

The classifcation script sorts clusters using time series data and supervised learning techniques. The script trains 3 models: a 1-D CNN, an MLP, and an LSTM. The LSTM is the main model while the other two are used for comparison. Each model is trained using a 70-30 train test split of the data provided and outputs a confusion matrix and an F1 score to show the accuracy of each model. Each cluster must contain at least two samples or else the confusion matrix will not be alligned due to the train test split. This can be controlled by the threshold parameter in the pbs script if the user wants to exclude clusters that only have a few samples. 

__Dependencies:__

- pandas
- numpy
- scikit-learn
- matplotlib
- seaborn
- tensorflow

__Data:__

The script takes a single csv file of RNA expression changes over time. The first row is the header containing the gene column, the different time steps, and the cluster column. The other rows contain the gene, RNA expressions at each time step, and the cluster it belongs to. The csv file must be in the 'data' directory. Multiple csv files can be in this directory and the script will output a results directory for each file. An example is shown below, this example has one feature, the RNA expression, and five time steps.
```       
gene                      0             12            24            48            72            clusters    
A17C_Medtr2g026050_rep2	  5.221980164   5.157623152   5.294473715   5.29495152    5.37787568    Mtr-Shoot-DTW-K50-045-DPGP001
A17R_Medtr7g059515_rep2	  0             0.403085897   0.091756243   0.140124224   0.125210248   Mtr-Shoot-DTW-K50-044-DPGP002
```

__PBS Script:__

The PBS script is used to submit a job on the palmetto cluster. The script loops through all the csv files in the 'data' and runs the classification on each file. The command line arguments can be changed in the pbs script and are as follows:
- file_name - The file name of the csv file. This is automatically grabbed in the script so it does not need to be changed.
- threshold - The minimum number of samples a cluster must have or else it is removed from the data. The default value is 2 and it can not be lower than 2.
- test_split - The percentage of data to split into a train-test set. The default value is 0.3 which splits the data into 70% train and 30% test. 
- epochs - The number of passes through the dataset to train the model. Default is 100.

__Output:__

The main output of the script is a confusion matrix and an F1 score for each model, these are created in a 'results' directory. The confusion matrix shows how well the trained model classified each sample from the test split. The expected values are on the y-axis and the predicted values are on the x-axis. This matrix is normalized to show a percentage of samples classfied. So if there are five genes in cluster A but the model predicted two of these genes are in cluster B, the cluster A row would could contain a 60 in column A and a 40 in column B. This normalization can be disabled in the confusion matrix function. The F1 scored is written to a text file

__Running:__
1. Verify all the dependencies are installed in an anaconda virual environment and the correct environment is set in the PBS script
2. Adjust command line arguments in the PBS script if desired
   - Additional parameters can be adjusted within the script itself
4. Correctly format data move it to the 'data' directory
5. On a palmetto login node enter the following command to submit the job
   - ```qsub cluster-sort.pbs``` 
 
