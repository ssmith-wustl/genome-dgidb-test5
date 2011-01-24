package Genome::InstrumentData::AlignmentResult::Mblastx;

use strict;
use warnings;
use File::Basename;
use File::Path;
use File::Copy;
use Genome;

class Genome::InstrumentData::AlignmentResult::Mblastx {
	is => 'Genome::InstrumentData::AlignmentResult',

	has_constant => [ aligner_name => { value => 'mblastx', is_param => 1 }, ],
	has          => [
		_max_read_id_seen  => { default_value => 0,       is_optional => 1 },
		_file_input_option => { default_value => 'fasta', is_optional => 1 },
	]
};

sub required_arch_os { 'x86_64' }

sub required_rusage {
"-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>32000] span[hosts=1] rusage[tmp=90000, mem=32000]' -M 32000000 -n 8 -m hmp -q hmp";
}

sub _decomposed_aligner_params {
	my $self = shift;

	my $aligner_params = ( $self->aligner_params || '' );

	my $cpu_count = $self->_available_cpu_count;
	$aligner_params .= " -T $cpu_count";

	return ( 'mblastx_aligner_params' => $aligner_params );
}

sub aligner_params_for_sam_header{
    my $self = shift;
    
    my %params = $self->_decomposed_aligner_params;
    my $aln_params = $params{mblastx_aligner_params};
    my $mblastx = $self->_mblastx_path;
    
    return "$mblastx $aln_params";
}

sub _mblastx_path{
    my $self = shift;
    return "/gscmnt/sata895/research/mmitreva/SOFTWARE/MCW_09242010/mblastx";
}

sub _run_aligner {
	my $self            = shift;
	my @input_pathnames = @_;

	if ( @input_pathnames == 1 ) {
		$self->status_message("_run_aligner called in single-ended mode.");
	} elsif ( @input_pathnames == 2 ) {
		$self->status_message(
"_run_aligner called in paired-end mode.  We don't actually do paired alignment with MBlastx though; running two passes."
		);
	} else {
		$self->error_message( "_run_aligner called with "
			  . scalar @input_pathnames
			  . " files.  It should only get 1 or 2!" );
		die $self->error_message;
	}

	# get refseq info

	my $reference_build = $self->reference_build;
    my $reference_name = $reference_build->prefix;
	my $reference_mblastx_path = $reference_build->data_directory . '/mblastx';

	# Check the local cache on the blade for the fasta if it exists.
	if ( -e "/opt/fscache/" . $reference_mblastx_path ) {
		$reference_mblastx_path = "/opt/fscache/" . $reference_mblastx_path;
	}

	my $scratch_directory = $self->temp_scratch_directory;
	my $staging_directory = $self->temp_staging_directory;

	my @mblastx_input_fastas;

	foreach my $i ( 0 ... $#input_pathnames ) {

		my $input_pathname = $input_pathnames[$i];

		my $chunk_path = $scratch_directory . "/chunks/chunk-from-" . $i;
		unless ( mkpath($chunk_path) ) {
			$self->error_message(
				"couldn't create a place to chunk the data in $chunk_path");
			die $self->error_message;
		}

 #________________________________________________________________________
 #   To run MCW, have to first convert fastq file into a fasta file using a utility script,
 #   for which you have to designate a destination directory


		#STEP 1 - convert input to fasta
		my $input_fasta = File::Temp::tempnam( $scratch_directory, "input-XXX" )
		  . ".fasta";    #destination of converted input


		my $fastq_to_fasta =  Genome::Model::Tools::Fastq::ToFasta->create(
												fastq_file => $input_pathname, fasta_file => $input_fasta);
		
		unless ($fastq_to_fasta->execute && -s $input_fasta){
			die  $self->error_message("Failed to convert fastq $input_pathname to fasta");
		}


		#		my $log_input  = $chunk_path . "/sdfsplit.log";
		#		my $log_output = $self->temp_staging_directory . "sdfsplit.log";
		#		$cmd = sprintf( 'cat %s >> %s', $log_input, $log_output );
		#
		#		Genome::Sys->shellcmd(
		#			cmd                       => $cmd,
		#			input_files               => [$log_input],
		#			output_files              => [$log_output],
		#			skip_if_output_is_present => 0
		#		);

		# chunk paths all have numeric names
#		for my $chunk ( grep { basename($_) =~ m/^\d+$/ }
#			glob( $chunk_path . "/*" ) )
#		{
#			$self->status_message("Adding chunk for analysis ... $chunk");
#			push @chunks, $chunk;
#		}
		push @mblastx_input_fastas, $input_fasta;

	}

   #____________________________________________________________________________
			$DB::single = 1;
	for my $input_fasta (@mblastx_input_fastas) {

		my $output_file =  $self->temp_scratch_directory."/".basename($input_fasta)."_vs_$reference_name"."_mblastx.out";

		#STEP 2 - run mblastx aligner
		my %aligner_params = $self->_decomposed_aligner_params;

		my $mblastx = $self->_mblastx_path;
		my $mblastx_aligner_params = (
			defined $aligner_params{'mblastx_aligner_params'}
			? $aligner_params{'mblastx_aligner_params'}
			: ""
		);
		my $cmd = sprintf( '%s -q %s -o %s %s',
			$mblastx, $input_fasta, $output_file, $mblastx_aligner_params );

		$self->status_message("mblastx data dir variable set to $ENV{MBLASTX_DATADIR}");
		local $ENV{MBLASTX_DATADIR} = $reference_mblastx_path;
		
		Genome::Sys->shellcmd(
			cmd                       => $cmd,
			input_files               => [$input_fasta],
			output_files              => [ $output_file ],
			skip_if_output_is_present => 0,
		);


        rename($output_file,$self->temp_staging_directory."/".basename($output_file));				

	}

	return 1;
}

#sub input_chunk_size {
#    return 3_000_000;
#}

sub _compute_alignment_metrics {
	return 1;
}

sub prepare_scratch_sam_file {
        return 1;
}

sub create_BAM_in_staging_directory {
	return 1;
}

sub postprocess_bam_file {
	return 1;
}

sub _prepare_reference_sequences {
	my $self            = shift;
	my $reference_build = $self->reference_build;

	my $dir = $reference_build->data_directory . '/mblastx';
	if ( -e $dir ) {
		$self->status_message("Found reference data at: $dir");
		return 1;
	}
	$self->status_message("No reference data found at: $dir");
	mkpath($dir);

	my $ref_basename =
	  File::Basename::fileparse( $reference_build->full_consensus_path('fa') );
	my $reference_fasta_path =
	  sprintf( "%s/%s", $reference_build->data_directory, $ref_basename );

	unless ( -e $reference_fasta_path ) {
		$self->error_message(
			"Alignment reference path $reference_fasta_path does not exist");
		die $self->error_message;
	}

	# generate a reference data set at $dir...
	my $mhashgen =
	  "/gscmnt/sata895/research/mmitreva/SOFTWARE/MCW_09242010/mhashgen";
   
    unless($self->mhashgen_format){
    	die $self->error_message("Database format option (--mhashgen-format=K/N) not provided.");
    }

	my $cmd = sprintf( '%s -s %s -T %s', $mhashgen, $reference_fasta_path, $self->mhashgen_format );

	local $ENV{MBLASTX_DATADIR} = $dir;

	#todo figure out how to copy the BLOSUM matrix

	Genome::Sys->shellcmd(
		cmd                       => $cmd,
		input_files               => [$reference_fasta_path],
		skip_if_output_is_present => 0,
	);

	$self->status_message("Reference data generation complete at: $dir");
	
	if(!-e "$dir/BLOSUM62_6_26.dat"){
		`cp /gscmnt/sata895/research/mmitreva/SOFTWARE/MCW_09242010/BLOSUM62_6_26.dat $dir/`;    
	}
	
	return 1;
}

