#!/usr/bin/tcsh

set srr_ids = $argv[1]
set sra_samples = $argv[2]
set picard_dir = $argv[3]
set tmp_dir = $argv[4]
set pwd = `pwd`

echo "Checking for appropriate scripts..."
set fastq_dump = `which fastq-dump | awk '{print NF}'`
set trimBWA = `which trimBWAstyle.usingBam.pl | awk '{print NF}'`

if ( $trimBWA > 1 ) then
	echo "Could not find trimBWAstyle.usingBAM.pl.  Please make sure this is in your path and try again."
	exit
endif

if ( $fastq_dump > 1 ) then 
        echo "Could not find fastq-dump.  Please make sure this is in your path and try again."
        exit
endif

foreach sample ( `grep -f $srr_ids $sra_samples | awk '{print $2}' | sort | uniq` )
	set runs = `grep $sample $sra_samples | awk '{print $1}' | sort | uniq | wc | awk '{print $1}'`
	set failSample = 0

	echo "`date` ${sample}: Processing $runs run(s)..."

	if (-d $sample ) then
		echo "`date` ${sample}: Removing existing files..."
		if (-e $sample/$sample.metadata) rm $sample/$sample.meta_data
		if (-e $sample/${sample}_1.fastq ) rm $sample/${sample}_1.fastq
		if (-e $sample/${sample}_2.fastq ) rm $sample/${sample}_2.fastq
		if (-e $sample/${sample}.singletons.fastq) rm $sample/${sample}.singletons.fastq
	else
		mkdir $sample
	endif	

	foreach srr_id ( `grep $sample $sra_samples | awk '{print $1}' | sort | uniq` )
		echo "\t`date` ${srr_id}: Checking download integrity... "
		if (-d $srr_id) then
			set orig_md5 = `cat $srr_id/col/READ/md5 | awk '$2 ~ /data/ {print $1}'`
			set new_md5 = `md5sum $srr_id/col/READ/data | awk '{print $1}'`
			#echo "Reported Checksum: $orig_md5"
			#echo "Downloaded Checksum: $new_md5"
			if ($orig_md5 == $new_md5) then
				#echo "md5 check! Good."
			else
				echo "\tERROR ${srr_id}: md5 does not check out.  Please remove this directory and retry your download." > $sample/$sample.ERR
				set failSample = 1
				continue
			endif
		else
			echo "No directory found for $srr_id.  Skipping." > $sample/$sample.ERR
			set failSample = 1
		endif

		echo "\t`date` ${srr_id}: Pulling meta data..."		
		wget 'http://www.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?run='$srr_id'&retmode=xml' -O $sample/$srr_id.xml >& /dev/null

		set sn = "sn"
		set ri = "ri"
	
		echo "\t`date` ${srr_id}: Pulling Fastqs from SRA data..."
		if (-e ${sample}/$srr_id.fastq) then
			echo "\tSKIPPING: ${sample}/$srr_id.fastq exists"
		else
			fastq-dump -A $srr_id -D $srr_id/ -DB '@$sn/$ri' -DQ '+$sn/$ri' -O $sample/ >& $sample/fastq-dump.out
		endif

		cat ${sample}/${srr_id}_1.fastq >> ${sample}/${sample}_1.fastq
		cat ${sample}/${srr_id}_2.fastq >> ${sample}/${sample}_2.fastq
		cat ${sample}/$srr_id.fastq >> ${sample}/$sample.singletons.fastq

		#rm ${sample}/${srr_id}_1.fastq
		#rm ${sample}/${srr_id}_2.fastq
		#rm ${sample}/${srr_id}.fastq
	end

	if ($failSample) then
		echo "Some runs could not be processed.   Skipping sample!"
		echo ""
		continue
	endif

	echo "\t`date` ${sample}: Converting Fastq to BAM..."
	if (! -e $sample/$sample.bam) then
		java -jar $picard_dir/FastqToSam.jar F1=$sample/{$sample}_1.fastq F2=$sample/${sample}_2.fastq O=$sample/$sample.bam V=Standard SAMPLE_NAME=$sample TMP_DIR=$tmp_dir >& FastqToSam.out
	else
		echo "\tSKIPPING: $sample/$sample.bam exists."
	endif

	echo "\t`date` ${sample}: Removing duplicates..."
	if (! -e ${sample}/$sample.denovo_duplicates_marked.bam) then
		java -jar $picard_dir/EstimateLibraryComplexity.jar I=${sample}/$sample.bam O=${sample}/$sample.denovo_duplicates_marked.bam METRICS_FILE=${sample}/$sample.denovo_duplicates_marked.metrics REMOVE_DUPLICATES=true TMP_DIR=$tmp_dir >& EstimateLibraryComplexity.out
	else
		echo "\tSKIPPING: $sample/$sample.denovo_duplicates_marked.bam exists."
	endif

	echo "\t`date` ${sample}: Trimming Q2 bases..."
	if (! -e ${sample}/$sample.duplicates_removed.Q2trimmed.fastq ) then
		trimBWAstyle.usingBam.pl -o 33 -q 3 -f ${sample}/$sample.denovo_duplicates_marked.bam
	else 
		echo "\tSKIPPING: ${sample}/$sample.duplicates_removed.Q2trimmed.fastq exists."
	endif

	echo "`date` ${sample}: Processing complete."
	echo ""
end
