
package Genome::InstrumentData::AlignmentResult::RtgMap;

use strict;
use warnings;
use File::Basename;
use File::Path;
use Genome;

class Genome::InstrumentData::AlignmentResult::RtgMap{
    is => 'Genome::InstrumentData::AlignmentResult',
    
    has_constant => [
        aligner_name => { value => 'rtg map', is_param=>1 },
    ],
    has => [
        _file_input_option =>   { default_value => 'fastq', is_optional => 1},
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>16000] span[hosts=1] rusage[tmp=90000, mem=16000]' -M 16000000 -n 4";
}

sub _decomposed_aligner_params {
    my $self = shift;

    #   -U produce unmapped sam
    #   -Z do not zip sam
    $ENV{'RTG_MEM'} = ($ENV{'TEST_MODE'} ? '1G' : '15G');
    $self->status_message("RTG Memory request is $ENV{RTG_MEM}");
    my $aligner_params = ($self->aligner_params || '') . " -U -Z "; #append core & space

    my $cpu_count = $self->_available_cpu_count;
    $aligner_params .= " -T $cpu_count";
    
    return ('rtg_aligner_params' => $aligner_params);
}

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    # get refseq info
    my $reference_build = $self->reference_build;
    
    my $reference_sdf_path = $reference_build->full_consensus_path('sdf');

    unless (-e $reference_sdf_path) {
        $self->error_message("sdf path not found in " . $reference_build->data_directory);
        die $self->error_message;
    }
    
    # Check the local cache on the blade for the fasta if it exists.
    if (-e "/opt/fscache/" . $reference_sdf_path) {
        $reference_sdf_path = "/opt/fscache/" . $reference_sdf_path;
    }

    my $scratch_directory = $self->temp_scratch_directory;
    
    my $staging_directory = $self->temp_staging_directory;
 
    #   To run RTG, have to first convert ref and inputs to sdf, with 'rtg format', for which you 
    #   have to designate a destination directory
 
    #STEP 1 - convert input to sdf
    my $input_sdf = File::Temp::tempnam($scratch_directory, "input-XXX") . ".sdf"; #destination of converted input
    my $output_dir = File::Temp::tempnam($scratch_directory, "output-XXX") . ".sdf";  
    my @output_files; 
    my $rtg_fmt = Genome::Model::Tools::Rtg->path_for_rtg_format($self->aligner_version);
    my $cmd;

    if (@input_pathnames == 1) {
        $self->status_message("_run_aligner called in single-ended mode.");
        $cmd = sprintf('%s --format=%s -o %s %s',
                        $rtg_fmt,
                        $self->_file_input_option,
                        $input_sdf,
                        $input_pathnames[0]);
        @output_files = ("$output_dir/alignments.sam", "$output_dir/unmapped.sam");
    } elsif (@input_pathnames == 2) {
        $self->status_message("_run_aligner called in paired-end mode.");
        $cmd = sprintf('%s --format=%s -o %s -l %s -r %s', #specify paired ends as "l" and "r"
                        $rtg_fmt,
                        $self->_file_input_option,
                        $input_sdf,
                        $input_pathnames[0],  
                        $input_pathnames[1]);
        @output_files = ("$output_dir/unmated.sam", "$output_dir/mated.sam", "$output_dir/unmapped.sam");
    } else {
        $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
        die $self->error_message;
    }
    
    Genome::Utility::FileSystem->shellcmd(
            cmd                 => $cmd, 
            input_files         => \@input_pathnames,
            output_directories  => [$input_sdf],
            skip_if_output_is_present => 0,
    );

    #check sdf output was created
    my @idx_files = glob("$input_sdf/*");
    if (!@idx_files > 0) {
        $self->error_message(sprintf("rtg formatting of [%s] failed  with %s", join " ", @input_pathnames, $cmd ));
        die $self->error_message;
    }
        
    #STEP 2 - run rtg map aligner  
    my %aligner_params = $self->_decomposed_aligner_params;
    my $rtg_map = Genome::Model::Tools::Rtg->path_for_rtg_map($self->aligner_version);
    my $rtg_aligner_params = (defined $aligner_params{'rtg_aligner_params'} ? $aligner_params{'rtg_aligner_params'} : "");
    $cmd = sprintf('%s -t %s -i %s -o %s %s ', 
                    $rtg_map,
                    $reference_sdf_path,
                    $input_sdf,
                    $output_dir,
                    $rtg_aligner_params);
    
    #rtg grabs all the CPU it can, so create restriction
        
    Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => [ $input_sdf ],
        output_files => [@output_files, "$output_dir/done"],
        skip_if_output_is_present => 0,
    );

    #STEP 3.0 - rename reads
    my @rr_files;
    foreach my $file_to_rr (@output_files)
    {
        my $rr_file = "$file_to_rr.rr";
        $cmd = sprintf('rtg samrename -i %s -o %s %s', 
                        $input_sdf, 
                        $rr_file,
                        $file_to_rr);

        Genome::Utility::FileSystem->shellcmd(
            cmd             => $cmd,
            input_files     => [$input_sdf, $file_to_rr],
            output_files    => [$rr_file],
            skip_if_output_is_present => 0,
        );

        push(@rr_files, $rr_file);
    }

    #STEP 3.1 - Collate, Format and Append sam files 
    my $sam_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $sam_file_fh = IO::File->new("> $sam_file");

    foreach my $file_to_append (@rr_files)
    {
        my $file_to_append_fh = IO::File->new( $file_to_append);
        while (<$file_to_append_fh>)
        {
            unless ($_ =~ /^@/) # eat headers
            {
                #fix CIGAR string - RTG puts in "=", replace with "M" - assumes 6th tabbed column    
                my @line = split ("\t", $_);
                $line[5]=~s/=/M/g;

                $sam_file_fh->print (join("\t", @line));
            }
        }
        $file_to_append_fh->close;
    }
    $sam_file_fh->close;

    # confirm that at the end we have a nonzero sam file, this is what'll get turned into a bam and copied out.
    unless (-s $sam_file) {
        die "The sam output file $sam_file is zero length; something went wrong.";
    }

    #STEP 4 - append log files 
    my $log_input = "$output_dir/map.log";
    my $log_output = $self->temp_staging_directory . "/rtg_map.log";
    $cmd = sprintf('cat %s >> %s', $log_input, $log_output);        

    Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => [ $log_input ],
        output_files => [ $log_output ],
        skip_if_output_is_present => 0,
    );

    # cleanup for the next pass, if there is one
    rmtree($output_dir);
    rmtree($input_sdf);
    
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;
    my $cmd = Genome::Model::Tools::Rtg->path_for_rtg_map($self->aligner_version);
    my %params = $self->_decomposed_aligner_params;
    my $aln_params = $params{rtg_aligner_params};
    
    return "$cmd $aln_params"; 
}

sub input_chunk_size {
    return 3_000_000;
}

sub fillmd_for_sam
{
    return 1;
}


