#!/bin/bash
################## BindCraft installation script
################## specify conda/mamba folder, and installation folder for git repositories, and whether to use mamba or $pkg_manager
# Default value for pkg_manager
pkg_manager='conda'
cuda=''

# Define the short and long options
OPTIONS=p:c:
LONGOPTIONS=pkg_manager:,cuda:

# Parse the command-line options
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
eval set -- "$PARSED"

# Process the command-line options
while true; do
  case "$1" in
    -p|--pkg_manager)
      pkg_manager="$2"
      shift 2
      ;;
    -c|--cuda)
      cuda="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo -e "Invalid option $1" >&2
      exit 1
      ;;
  esac
done

# Example usage of the parsed variables
echo -e "Package manager: $pkg_manager"
echo -e "CUDA: $cuda"

############################################################################################################
############################################################################################################
################## initialisation
SECONDS=0

# set paths needed for installation and check for conda installation
install_dir=$(pwd)
# CONDA_BASE=$(conda info --base 2>/dev/null) || { echo -e "Error: conda is not installed or cannot be initialised."; exit 1; }
# echo -e "Conda is installed at: $CONDA_BASE"

### BindCraft install begin, create base environment
echo -e "Installing BindCraft_git environment\n"
$pkg_manager create --name BindCraft_git python=3.10 -y || { echo -e "Error: Failed to create BindCraft_git conda environment"; exit 1; }
conda env list | grep -w 'BindCraft_git' >/dev/null 2>&1 || { echo -e "Error: Conda environment 'BindCraft_git' does not exist after creation."; exit 1; }

# Load newly created BindCraft_git environment
echo -e "Loading BindCraft_git environment\n"
source /scicore/home/schwede/follon0000/mambaforge/bin/activate /scicore/home/schwede/follon0000/mambaforge/envs/BindCraft_git || { echo -e "Error: Failed to activate the BindCraft_git environment."; exit 1; } #${CONDA_BASE}
[ "$CONDA_DEFAULT_ENV" = "BindCraft_git" ] || { echo -e "Error: The BindCraft_git environment is not active."; exit 1; }
echo -e "BindCraft_git environment activated at /scicore/home/schwede/follon0000/mambaforge/envs/BindCraft_git"

# install required conda packages
echo -e "Instaling conda requirements\n"
if [ -n "$cuda" ]; then
    CONDA_OVERRIDE_CUDA="$cuda" $pkg_manager install pip pandas matplotlib numpy"<2.0.0" biopython scipy pdbfixer seaborn libgfortran5 tqdm jupyter ffmpeg pyrosetta fsspec py3dmol chex dm-haiku flax"<0.10.0" dm-tree joblib ml-collections immutabledict optax jaxlib=*=*cuda* jax cuda-nvcc cudnn -c conda-forge -c nvidia  --channel https://conda.graylab.jhu.edu -y || { echo -e "Error: Failed to install conda packages."; exit 1; }
else
    $pkg_manager install pip pandas matplotlib numpy"<2.0.0" biopython scipy pdbfixer seaborn libgfortran5 tqdm jupyter ffmpeg pyrosetta fsspec py3dmol chex dm-haiku flax"<0.10.0" dm-tree joblib ml-collections immutabledict optax jaxlib jax cuda-nvcc cudnn -c conda-forge -c nvidia  --channel https://conda.graylab.jhu.edu -y || { echo -e "Error: Failed to install conda packages."; exit 1; }
fi

# make sure all required packages were installed
required_packages=(pip pandas libgfortran5 matplotlib numpy biopython scipy pdbfixer seaborn tqdm jupyter ffmpeg pyrosetta fsspec py3dmol chex dm-haiku dm-tree joblib ml-collections immutabledict optax jaxlib jax cuda-nvcc cudnn)
missing_packages=()

# Check each package
for pkg in "${required_packages[@]}"; do
    conda list "$pkg" | grep -w "$pkg" >/dev/null 2>&1 || missing_packages+=("$pkg")
done

# If any packages are missing, output error and exit
if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "Error: The following packages are missing from the environment:"
    for pkg in "${missing_packages[@]}"; do
        echo -e " - $pkg"
    done
    exit 1
fi

# install ColabDesign
echo -e "Installing ColabDesign\n"
pip3 install git+https://github.com/sokrypton/ColabDesign.git --no-deps || { echo -e "Error: Failed to install ColabDesign"; exit 1; }
python -c "import colabdesign" >/dev/null 2>&1 || { echo -e "Error: colabdesign module not found after installation"; exit 1; }

# # AlphaFold2 weights
# echo -e "Downloading AlphaFold2 model weights \n"
# params_dir="${install_dir}/params"
# params_file="${params_dir}/alphafold_params_2022-12-06.tar"

# # download AF2 weights
# mkdir -p "${params_dir}" || { echo -e "Error: Failed to create weights directory"; exit 1; }
# wget -O "${params_file}" "https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar" || { echo -e "Error: Failed to download AlphaFold2 weights"; exit 1; }
# [ -s "${params_file}" ] || { echo -e "Error: Could not locate downloaded AlphaFold2 weights"; exit 1; }

# # extract AF2 weights
# tar tf "${params_file}" >/dev/null 2>&1 || { echo -e "Error: Corrupt AlphaFold2 weights download"; exit 1; }
# tar -xvf "${params_file}" -C "${params_dir}" || { echo -e "Error: Failed to extract AlphaFold2weights"; exit 1; }
# [ -f "${params_dir}/params_model_5_ptm.npz" ] || { echo -e "Error: Could not locate extracted AlphaFold2 weights"; exit 1; }
# rm "${params_file}" || { echo -e "Warning: Failed to remove AlphaFold2 weights archive"; }

# chmod executables
echo -e "Changing permissions for executables\n"
chmod +x "${install_dir}/functions/dssp" || { echo -e "Error: Failed to chmod dssp"; exit 1; }
chmod +x "${install_dir}/functions/DAlphaBall.gcc" || { echo -e "Error: Failed to chmod DAlphaBall.gcc"; exit 1; }

# finish
conda deactivate
echo -e "BindCraft_git environment set up\n"

############################################################################################################
############################################################################################################
################## cleanup
echo -e "Cleaning up ${pkg_manager} temporary files to save space\n"
$pkg_manager clean -a -y
echo -e "$pkg_manager cleaned up\n"

################## finish script
t=$SECONDS 
echo -e "Successfully finished BindCraft_git installation!\n"
echo -e "Activate environment using command: \"$pkg_manager activate BindCraft_git\""
echo -e "\n"
echo -e "Installation took $(($t / 3600)) hours, $((($t / 60) % 60)) minutes and $(($t % 60)) seconds."