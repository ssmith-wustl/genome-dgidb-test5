package Genome::InstrumentData::AlignmentResult::Mosaik;

use strict;
use warnings;
use File::Basename;

use Genome;

class Genome::InstrumentData::AlignmentResult::Mosaik {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'Mosaik', is_param=>1 },
    ],
    has_optional => [
         _Mosaik_sam_cmd => { is=>'Text' }
    ]
};

sub required_arch_os { 'x86_64' }

# fill me in here with what compute resources you need.
sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>4000] span[hosts=1] rusage[tmp=90000, mem=4000]' -M 24000000 -n 8";
}

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;
    
    my $tmp_dir = $self->temp_scratch_directory;
    my $tmp_reads_file = "$tmp_dir/reads.dat"; 
    my $tmp_align_file = "$tmp_dir/aligned.dat";
    my $tmp_unalign_fq_file = "$tmp_dir/unaligned.fastq";
    my $tmp_unalign_sam_file = "$tmp_dir/unaligned.sam";
    my $tmp_sort_file = "$tmp_dir/sorted.dat";
    my $tmp_sam_file = "$tmp_dir/aligned_mosaik.sam";
    my $staging_sam_file = "$tmp_dir/all_sequences.sam";
    
    # get refseq info
    my $reference_build = $self->reference_build;
    #my $ref_basename = File::Basename::fileparse($reference_build->full_consensus_path('fa'));
    #my $ref_basename = File::Basename::fileparse("/gscmnt/sata820/info/medseq/alignment-test/mosaik_x64/test/reference.dat"
    #my $ref_jump_basename = File::Basename::fileparse("/gscmnt/sata820/info/medseq/alignment-test/mosaik_x64/test/reference_15"
    #my $reference_fasta_path = sprintf("%s/%s", $reference_build->data_directory, $ref_basename);

    my $ref_file = "/gscmnt/sata820/info/medseq/alignment-test/mosaik_x64/test/reference.dat";
    my $jump_file = "/gscmnt/sata820/info/medseq/alignment-test/mosaik_x64/test/reference_15";
     
    my $mosaik_build_path = Genome::Model::Tools::Mosaik->path_for_mosaik_version($self->aligner_version)."Build";
    my $mosaik_align_path = Genome::Model::Tools::Mosaik->path_for_mosaik_version($self->aligner_version)."Aligner";
    my $mosaik_sort_path = Genome::Model::Tools::Mosaik->path_for_mosaik_version($self->aligner_version)."Sort";
    my $mosaik_text_path = Genome::Model::Tools::Mosaik->path_for_mosaik_version($self->aligner_version)."Text";

    my $align_cmdline;
    my $sort_cmdline;
    
    my %aligner_params = $self->decomposed_aligner_params;

    #### STEP 1: Convert fastq files to binary format used by Mosaik
    #### TODO needs support for fasta?
    
    if (scalar(@input_pathnames) == 2) {
        my $cmdline = $mosaik_build_path . sprintf(' -q %s -q2 %s -out %s %s',
            $input_pathnames[0], $input_pathnames[1], $tmp_reads_file, $aligner_params{mosaik_build_params});

        Genome::Utility::FileSystem->shellcmd(
            cmd             => $cmdline,
            input_files     => [ $input_pathnames[0], $input_pathnames[1] ],
            output_files    => [ $tmp_reads_file ],
            skip_if_output_is_present => 0,
        );

        unless (-s $tmp_reads_file) {
            $self->error_message("Unable to convert reads at $input_pathnames[0] and $input_pathnames[1] into binary Mosaik file $tmp_reads_file");
            $self->die_and_clean_up($self->error_message);
        }

    } elsif (scalar(@input_pathnames) == 1) {
        my $cmdline = $mosaik_build_path . sprintf(' -q %s -out %s %s',
            $input_pathnames[0], $tmp_reads_file, $aligner_params{mosaik_build_params});
        
        Genome::Utility::FileSystem->shellcmd(
            cmd             => $cmdline,
            input_files     => [ $input_pathnames[0] ],
            output_files    => [ $tmp_reads_file ],
            skip_if_output_is_present => 0,
        );
        
        unless (-s $tmp_reads_file) {
            $self->error_message("Unable to convert reads at $input_pathnames[0] into binary Mosaik file $tmp_reads_file");
            $self->die_and_clean_up($self->error_message);
        }

    } else {
        $self->error_message("number of input pathnames to Mosaik was not 1 or 2");
        $self->die_and_clean_up($self->error_message);
    }
    
    #### STEP 2: Align
    
    {
        $align_cmdline = $mosaik_align_path . sprintf(' -in %s -out %s -ia %s -rur %s %s -j %s',
            $tmp_reads_file, $tmp_align_file, $ref_file, $tmp_unalign_fq_file, $aligner_params{mosaik_align_params}, $jump_file);
        
        Genome::Utility::FileSystem->shellcmd(
            cmd             => $align_cmdline,
            input_files     => [ $tmp_reads_file, $ref_file, $jump_file."_keys.jmp", $jump_file."_meta.jmp", $jump_file."_positions.jmp" ],
            output_files    => [ $tmp_align_file, $tmp_unalign_fq_file ],
            skip_if_output_is_present => 0,
        );

        Genome::Model::Tools::Sam::FastqToSam->execute(
                fastq_file => $tmp_unalign_fq_file,
                sam_file   => $tmp_unalign_sam_file,
        );

        unless (-s $tmp_align_file) {
            $self->error_message("Unable to align. Alignment file $tmp_align_file is zero length, so something went wrong.");
            $self->die_and_clean_up($self->error_message);
        }

    }
    

    #### STEP 3: Sort & Pair
    
    {
        $sort_cmdline = $mosaik_sort_path . sprintf(' -in %s -out %s %s',
            $tmp_align_file, $tmp_sort_file, $aligner_params{mosaik_sort_params});

        Genome::Utility::FileSystem->shellcmd(
            cmd             => $sort_cmdline,
            input_files     => [ $tmp_align_file ],
            output_files    => [ $tmp_sort_file ],
            skip_if_output_is_present => 0,
        );

        unless (-s $tmp_sort_file) {
            $self->error_message("Unable to sort. Sorted file $tmp_sort_file is zero length, so something went wrong.");
            $self->die_and_clean_up($self->error_message);
        }

    }
    
    #### STEP 4: Convert & Clean
    
    {
        my $cmdline = $mosaik_text_path . sprintf(' -in %s -sam %s %s',
            $tmp_align_file, $tmp_sam_file, $aligner_params{mosaik_text_params});

        Genome::Utility::FileSystem->shellcmd(
            cmd             => $cmdline." && gunzip -d ".$tmp_sam_file.".gz",
            input_files     => [ $tmp_align_file ],
            output_files    => [ $tmp_sam_file ],
            skip_if_output_is_present => 0,
        );

        unless (-s $tmp_sam_file) {
            $self->error_message("Unable to convert back to sam. Sam file $tmp_sam_file is zero length, so something went wrong.");
            $self->die_and_clean_up($self->error_message);
        }

        # put your output file here, append to this file!
            #my $output_file = $self->temp_staging_directory . "/all_sequences.sam"
        # TODO uhhh is this totally right?
        die "Failed to process sam command line, error_message is ".$self->error_message unless $self->_filter_sam_output($tmp_sam_file, $tmp_unalign_sam_file, $staging_sam_file);

    }

    # TODO something to do with log files

    return 1;
}

sub _filter_sam_output {
    my ($self, $mosaik_output_sam_file, $unaligned_sam_file, $all_sequences_sam_file) = @_;

#    my $sam_run_output_fh = IO::File->new( $sam_cmd . "|" );
#    $self->status_message("Running $sam_cmd");
#    if ( !$sam_run_output_fh ) {
#            $self->error_message("Error running $sam_cmd $!");
#            return;
#    }

    my $mosaik_fh = IO::File->new( $mosaik_output_sam_file );
    if ( !$mosaik_fh ) {
            $self->error_message("Error opening mosaik output sam file for reading $!");
            return;
    }
    $self->status_message("Opened $mosaik_output_sam_file");

    my $unaligned_fh = IO::File->new( $unaligned_sam_file );
    if ( !$unaligned_fh ) {
            $self->error_message("Error opening unaligned sam file for reading $!");
            return;
    }
    $self->status_message("Opened $unaligned_sam_file");

    my $all_seq_fh = IO::File->new(">>$all_sequences_sam_file");
    if ( !$all_seq_fh ) {
        $self->error_message("Error opening all seq sam file for writing $!");
        return;
    }
    $self->status_message("Opened $all_sequences_sam_file");
    
    while (<$mosaik_fh>) {
        #write out the aligned map, excluding the default header- all lines starting with @.
        $all_seq_fh->print($_) unless $_ =~ /^@/;
#        my $first_char = substr($_,0,1);
#            if ($first_char ne '@') {
#            $all_seq_fh->print($_);
#        }
    }

    # TODO may already be filtered of header
    while (<$unaligned_fh>) {
        #write out the aligned map, excluding the default header- all lines starting with @.
        $all_seq_fh->print($_) unless $_ =~ /^@/;
#        my $first_char = substr($_,0,1);
#            if ($first_char ne '@') {
#            $all_seq_fh->print($_);
#        }
    }
    $mosaik_fh->close;
    $unaligned_fh->close;
    $all_seq_fh->close;
    return 1;
}

sub decomposed_aligner_params {
    my $self = shift;
    # TODO i think this comparison is unecessary if we push on the defaults like below
    #my $params = $self->aligner_params || "-st illumina:-hs 15 -mm 4 -mhp 100 -act 20 -p 8::";
    my $params = $self->aligner_params || "-st illumina:-hs 15 -mm 12 -mhp 100 -act 35 -p 8 -bw 29::";
    # TODO SHOULD NOT BE FORCING BUT SHIT IS BROKEN.
    #my $params = "-st illumina:-hs 15 -mm 12 -mhp 100 -act 35 -p 8 -bw 29::";
    
    my @spar = split /\:/, $params;
    # TODO this forcing of these default parameters (unless they're otherwise specified) could be... bad...
    if ($spar[0] !~ /-st/) { $spar[0] .= "-st illumina"; }
    if ($spar[1] !~ /-hs/) { $spar[1] .= "-hs 15"; }
    if ($spar[1] !~ /-mm/) { $spar[1] .= "-mm 12"; }
    if ($spar[1] !~ /-mhp/) { $spar[1] .= "-mhp 100"; }
    if ($spar[1] !~ /-act/) { $spar[1] .= "-act 35"; }
    if ($spar[1] !~ /-bw/) { $spar[1] .= "-bw 29"; }
    # this one seems pretty necessary, though. TODO if only there was a way to influence required_rusage based off of this
    if ($spar[1] !~ /-p/) { $spar[1] .= "-p 8"; }

    # TODO this is useless? since it doesn't check via aligner_params_for_sam_header anyways...
    # sort variables
    # TODO while on the one hand this ensures that specifiying the same params in a different order
    #   looks the same to aligner_params_for_sam_header, this could screw things up if the binaries
    #   expect things in a certain order.
#    foreach (@spar) {
#        # split by argument
#        $_ = [split /\s?\-/, $_];
#        # the first element should be empty, so drop it
#        shift @{$_};
#        # sort
#        @{$_} = sort @{$_};
#        # holder
#        my $ordered;
#        # push ordered args on
#        foreach (@{$_}) { $ordered .= "-$_ "; }
#        # set
#        $_ = $ordered;
#        # chop single trailing whitespace from loop
#        chop;
#    }

    return ('mosaik_build_params' => $spar[0], 'mosaik_align_params' => $spar[1], 'mosaik_sort_params' => $spar[2], 'mosaik_text_params' => $spar[3]);
}

sub aligner_params_for_sam_header {
    my $self = shift;
    
    my %params = $self->decomposed_aligner_params;
    
    return "MosaikBuild $params{mosaik_build_params}; MosaikAlign $params{mosaik_align_params}; MosaikSort $params{mosaik_sort_params}; MosaikText $params{mosaik_sort_params}";

    # for bwa this looks like "bwa aln -t4; bwa samse 12345'
}
