#!/bin/bash

# TO RUN: type in command line:
# bash full_process_no_b2000.sh or use autocomplete by pressing the tab key

# Last edited on 23/03/2019
# runs topup + eddy
# this script creates a new dwi file without the b2000 volumes by extracting
# everything else and merging them
# Also runs eddy no matter your computer (mac or linux VM)

# TO DO:
# make sure the data acquisition file is named acq_param.txt and ONLY has 2 lines
# make sure there is only 45 lines in the index file
# Download the extract.py file and drop it the folder with the data and this script


read -p "Input your subject and press Enter: " subject

full_file="Olf_Blind_"$subject"_dwi"
acq_param="acq_param.txt"
index="index.txt"
b0_file="Olf_Blind_"$subject"_b0"


# progress bar magic
prog() {
    local w=80 p=$1;  shift
    # create a string of spaces, then change them to dots
    printf -v dots "%*s" "$(( $p*$w/100 ))" ""; dots=${dots// /.};
    # print those dots on a fixed-width space plus the percentage etc.
    printf "\r\e[K|%-*s| %3d %% %s" "$w" "$dots" "$p" "$*";
}


# Creating the right dwi file
# extract the useful b value volumes from the dwi
i=1
for vol in 0 1 3 6 9 11 14 17 18 21 24 26 29 32 33 36 39 41 44 47 49 51 54 56 59 62 65 66 69 71 74 77 80 81 84 86 89 92 95 97 99 101 104 107 108
do
 fslroi $full_file $vol"_dwi" $vol 1
  perc=$((i*100/45))
  prog "$perc"
  echo -ne Still extracting...
  i=$((i+1))
done


# add all the extracted volumes to one argument
merged_argument=''
for n in 0 1 3 6 9 11 14 17 18 21 24 26 29 32 33 36 39 41 44 47 49 51 54 56 59 62 65 66 69 71 74 77 80 81 84 86 89 92 95 97 99 101 104 107 108
do
  merged_argument+=$n"_dwi "
done


# merging all the extracted volumes to a new dwi file
echo merging extracted volumes into a new dwi file
fslmerge -t $subject"merged_dwi" $merged_argument

newfile=$subject"merged_dwi"

#adding extra slice for topup
fslroi $newfile $newfile"_extra_slice" 0 -1 0 -1 0 58
echo adding extra slice

# truncating the individual b value files
echo removing individual b value files
for n in 0 1 3 6 9 11 14 17 18 21 24 26 29 32 33 36 39 41 44 47 49 51 54 56 59 62 65 66 69 71 74 77 80 81 84 86 89 92 95 97 99 101 104 107 108
do
  `rm $n"_dwi.nii.gz"`
done


# creating the right b0 files
# extract the first b0 volume from the dwi
for vol in 49
do
  fslroi $full_file $vol"_b0_dwi" $vol 1
  echo Extracting volume $vol from dwi
done


# extract the first b0 volume from raw b0
for vol in 2
do
  fslroi $b0_file $vol"_b0_raw" $vol 1
  echo Extracting volume $vol from raw b0
done

# merge all the extracted b0 into one file
# this order reverses the acq_param file!
# change the number before the "" if your extracted b0s are not 2 and 49
fslmerge -t merged_2b0 2"_b0_raw" 49"_b0_dwi"


# adding extra slices to the merged_b0 file for topup to run
echo Adding slices
fslroi merged_2b0 2b0_extra_slice 0 -1 0 -1 0 58

# removing the two extracted b0 files
rm 2"_b0_raw"
rm 49"_b0_dwi"

# creating the right bvecs and bvals
python extract.py $subject

# top up starts here
echo topup of $subject started at:
echo $(date +%r)
start=$SECONDS
topup --imain=2b0_extra_slice --datain=$acq_param --config=b02b0.cnf --out="topup_"$full_file --iout="b0_topup_"$subject
end=$SECONDS
duration=$((end-start))
echo topup of $subject is completed at:
echo $(date +%r)
echo It took $(($duration / 3600)) hours $((($duration % 3600) / 60)) minutes to topup $subject


# using BET tool
echo creating brain mask
topup_file="b0_topup_"$subject
brain_file=$subject"_brain"
bet $topup_file $brain_file -m -f 0.3


# setting file names for eddy
full_file="Olf_Blind_"$subject"_dwi"
acq_param="acq_param.txt"
index="index.txt"
b0_file="Olf_Blind_"$subject"_b0"
newfile=$subject"merged_dwi"
extra_slice_file=$newfile"_extra_slice"
bvec_file=new_$subject.bvec
bval_file=new_$subject.bval
out_file="eddy_corrected_"$subject
topup_file="b0_topup_"$subject
brain_file=$subject"_brain"
mask_file=$brain_file"_mask"


# running eddy
echo eddy correction of $subject started at:
echo $(date +%r)
start=$SECONDS


if eddy --imain=$extra_slice_file --mask=$mask_file --index=$index --acqp=$acq_param --bvecs=$bvec_file --bvals=$bval_file --topup="topup_Olf_Blind_"$subject"_dwi" --out=$out_file ; then
  echo "success: eddy runs normally"

else	# creates a condition to run eddy_openmp if eddy won't run (for VMs)
  echo "running eddy_openmp instead"
  eddy_openmp --imain=$extra_slice_file --mask=$mask_file --index=$index --acqp=$acq_param --bvecs=$bvec_file --bvals=$bval_file --topup="topup_Olf_Blind_"$subject"_dwi" --out=$out_file
fi

end=$SECONDS
duration=$((end-start))
echo eddy correction of $subject is completed at:
echo $(date +%r)
echo It took $(($duration / 3600)) hours $((($duration % 3600) / 60)) minutes to eddy correct $subject


echo "Thanks for using my scripts!"
echo "Goodbye"
echo "uwu"
