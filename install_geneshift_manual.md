## Install and Run Geneshift on google cloud virtual machine

### Create a virtual machine
- Note: parts of GeneShift can be memory hungry. I recommend getting a compute-optimized instance with >240 gb of RAM for large datasets
- OS should be CentOS7 with 2000 gb of storage

### Install dependencies
- Install openPBS
- Install git

		sudo yum install git
- Clone openPBS repository from github

		git clone https://github.com/openpbs/openpbs.git

- Install openPBS dependencies (part 1)

		sudo yum install -y gcc make rpm-build libtool hwloc-devel \
      	libX11-devel libXt-devel libedit-devel libical-devel \
      	ncurses-devel perl postgresql-devel postgresql-contrib python3-devel tcl-devel \
      	tk-devel swig expat-devel openssl-devel libXext libXft \
      	autoconf automake gcc-c++

- Install openPBS dependencies (part 2)

		sudo yum install -y expat libedit postgresql-server postgresql-contrib python3 \
      	sendmail sudo tcl tk libical

- Move into the openpbs directory

		cd openpbs

- Run the following commands:

		#First run this
		./autogen.sh

		#Then this
		./configure --prefix=/opt/pbs

		#Then this
		make

		#Finally, this
		sudo make install

- Now run this post-install command:

		sudo /opt/pbs/libexec/pbs_postinstall

- Install nano

		sudo yum install nano

- Change config file

		sudo nano /etc/pbs.conf

- Edit the config file line: `PBS_START_MOM=0` to `PBS_START_MOM=1`
- Save and close the pbs.conf file
- Change file permissions:

		sudo chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp

- Start PBS services:

		sudo /etc/init.d/pbs start

- Install anaconda

		curl -O https://repo.anaconda.com/archive/Anaconda3-5.3.1-Linux-x86_64.sh
		bash Anaconda3-5.3.1-Linux-x86_64.sh

- Follow prompts for installation

### Installing GeneShift
- create the appropriate conda environments and install the required libraries

		conda create -n GeneShift_env python=3.6 matplotlib numpy pandas scikit-learn 

		# tslearn needs to be installed separately.
		conda activate GeneShift_env
		
		conda install -c conda-forge tslearn
		
		conda deactivate
		
		conda create -n DPGP_env python=2.7 pandas numpy scipy matplotlib

		conda activate DPGP_env

		conda install -c conda-forge gpy

		conda deactivate

		conda create -n deep-learning python=3.6 matplotlib numpy pandas scikit-learn argparse os math collections
		
		conda activate deep-learning

		conda install -c anaconda h5py

		conda install -c conda-forge tslearn

		conda deactivate

### Clone updated GeneShift scripts from my github 
- Clone directory

		git clone https://github.com/mclear73/GeneShift-1.git

### Reference Materials
- [GeneShift github](https://github.com/yueyaog/GeneShift)
- [openPBS github](https://github.com/openpbs/openpbs)