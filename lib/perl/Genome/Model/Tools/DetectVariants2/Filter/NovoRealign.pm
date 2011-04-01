#ReAlign BreakDancer SV supporting reads using novoalign and produce a bam file
package Genome::Model::Tools::DetectVariants2::Filter::NovoRealign;

use strict;
use warnings;
use Genome;
use File::Copy;
use File::Basename;

class Genome::Model::Tools::DetectVariants2::Filter::NovoRealign {
    is  => 'Genome::Model::Tools::DetectVariants2::Filter',
    has_optional => [
        config_file => {
            calculate_from => 'detector_directory',
            calculate => q{ return $detector_directory.'/breakdancer_config';},
            doc  => 'breakdancer config file',
        },
        pass_staging_output => {
            is => 'FilePath',
            calculate_from => '_temp_staging_directory',
            calculate => q{ return $_temp_staging_directory . '/svs.hq'; },
        },
        fail_staging_output => {
            is => 'FilePath',
            calculate_from => '_temp_staging_directory',
            calculate => q{ return $_temp_staging_directory . '/svs.lq'; },
        },
        novoalign_version => {
            type => 'String',
            doc  => 'novoalign version to use in this process',
            default_value =>  '2.05.13',  #originally used in kchen's perl script, other version not tested
            valid_values  => [Genome::Model::Tools::Novocraft->available_novocraft_versions],
        },
        novoalign_path => {
            type => 'String',
            doc  => 'novoalign executeable path to use',
            calculate_from => 'novoalign_version',
            calculate => q{ return Genome::Model::Tools::Novocraft->path_for_novocraft_version($novoalign_version); },
        },
        novo2sam_path => {
            type => 'String',
            doc  => 'Path to novosam.pl',
            calculate_from => 'novoalign_version',
            calculate => q{ return Genome::Model::Tools::Novocraft->path_for_novosam_version($novoalign_version); },
        },
        platform => {
            type => 'String',
            doc  => 'Path to novoalign reference sequence index',
            default_value => 'SLX',
        },
        samtools_version => {
            type => 'String',
            doc  => 'samtools version to use in this process',
            default_value =>  Genome::Model::Tools::Sam->default_samtools_version,
            valid_values  => [Genome::Model::Tools::Sam->available_samtools_versions],
        },
        samtools_path => {
            type => 'String',
            calculate_from => 'samtools_version',
            calculate => q{ return Genome::Model::Tools::Sam->path_for_samtools_version($samtools_version); },
            doc => 'path to samtools executable',
        },
        breakdancer_path => {
            type => 'String',
            calculate_from => 'detector_version',
            calculate => q{ return Genome::Model::Tools::Breakdancer->breakdancer_max_command_for_version($detector_version); },
            doc => 'path to breakdancer executable',
        },

    ],
    has_param => [
        lsf_resource => {
            #default_value => "-R 'select[mem>8000] rusage[mem=8000]' -M 8000000", #novoalign needs this memory usage 8G to run
            default_value => "-R 'select[localdata && mem>10000] rusage[mem=10000]' -M 10000000",
        },
    ],
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'svs',
            doc => 'variant type that this module operates on, overload this in submodules accordingly',
        },
    ],
};


sub _filter_variants {
    my $self     = shift;
    my $cfg_file = $self->config_file;

    $ENV{GENOME_SYS_NO_CLEANUP} = 1;

    #Allow 0 size of output
    if (-z $cfg_file) {
        $self->warning_message('0 size of breakdancer config file. Probably it is for testing of samll bam files');
        my $output_file = $self->pass_staging_output;
        `touch $output_file`;
        return 1;
    }

    my (%mean_insertsize, %std_insertsize, %readlens);

    my $fh = Genome::Sys->open_file_for_reading($cfg_file) or die "unable to open config file: $cfg_file";
    while (my $line = $fh->getline) {
        next unless $line =~ /\S+/;
        chomp $line;
        my ($mean)   = $line =~ /mean\w*\:(\S+)\b/i;
        my ($std)    = $line =~ /std\w*\:(\S+)\b/i;
        my ($lib)    = $line =~ /lib\w*\:(\S+)\b/i;
        my ($rd_len) = $line =~ /readlen\w*\:(\S+)\b/i;

        ($lib) = $line =~ /samp\w*\:(\S+)\b/i unless defined $lib;
        $mean_insertsize{$lib} = int($mean + 0.5);
        $std_insertsize{$lib}  = int($std  + 0.5);
        $readlens{$lib}        = $rd_len;
    }
    $fh->close;

    my %fastqs;
    my $dir = $self->detector_directory;

    opendir (DIR, $dir) or die "Failed to open directory $dir\n";
    my $prefix;
    for my $fastq (grep{/\.fastq/} readdir(DIR)){
        for my $lib (keys %mean_insertsize) {
            #if ($fastq =~/^(\S+)\.\S+${lib}\.\S*([12])\.fastq/) {
            if ($fastq =~/^(\S+)\.${lib}\.\S*([12])\.fastq/) {
                $prefix = $1;
                my $id  = $2;
                #push @{$fastqs{$lib}{$id}}, $fastq if defined $id;
                push @{$fastqs{$lib}{$id}}, $dir.'/'.$fastq if defined $id;
                last;
            }
        }
    }
    closedir(DIR);

    #Move breakdancer_config to output_directory so TigraValidation
    #can use it to parse out skip_libraries
    if (-s $cfg_file) {
        copy $cfg_file, $self->_temp_staging_directory;
    }
    else {
        $self->warning_message("Failed to find breakdancer_config from detector_directory: $dir");
    }

    $prefix = $self->_temp_staging_directory . "/$prefix";

    my @bams2remove; 
    my @librmdupbams;
    my @novoaligns;
    my %headerline;

    my $novo_path     = $self->novoalign_path;
    my $novosam_path  = $self->novo2sam_path;
    my $samtools_path = $self->samtools_path;

    #my $ref_seq_model = Genome::Model::ImportedReferenceSequence->get(name => 'NCBI-human');
    #my $ref_seq_dir   = $ref_seq_model->build_by_version('36')->data_directory;
    #my $ref_seq_idx   = $ref_seq_dir.'/all_sequences.fasta.fai';
    my $ref_seq     = $self->reference_sequence_input;
    my $ref_seq_idx = $ref_seq . '.fai';
    unless (-s $ref_seq_idx) {
        $self->error_message("Failed to find ref seq fasta index file: $ref_seq_idx");
        die;
    }

    # TODO This can be changed when reference seuqnece build id is added to the filter api
    my $build_id;
    if ($ref_seq =~ /build(\d+)/) {
        $build_id = $1;
    }
    else {
        die "Could not get build id from reference sequence fasta file path $ref_seq";
    }

    my $novo_idx_obj = Genome::Model::Build::ReferenceSequence::AlignerIndex->get_or_create(
        reference_build_id => $build_id,
        aligner_version => $self->novoalign_version,
        aligner_name => 'novocraft',
        aligner_params => '-k 14 -s 3',
    );
    unless (defined $novo_idx_obj) {
        die "Could not retrieve novocraft index for reference build $build_id and aligner version " . $self->novoalign_version;
    }

    my $novo_idx = $novo_idx_obj->full_consensus_path('fa.novocraft');
    unless (-e $novo_idx) {
        die "Found no novocraft index file at $novo_idx for reference build $build_id and aligner version " . $self->novoalign_version;
    }

    for my $lib (keys %fastqs) {
        my @read1s = @{$fastqs{$lib}{1}};
        my @read2s = @{$fastqs{$lib}{2}};
        my $line   = sprintf "\@RG\tID:%s\tPU:%s\tLB:%s", $lib, $self->platform, $lib;
        $headerline{$line} = 1;
        my @bams;
        my $cmd;
        for (my $i=0; $i<=$#read1s; $i++) {
            my $fout_novo = "$prefix.$lib.$i.novo";
            $cmd = $novo_path . ' -d '. $novo_idx . " -f $read1s[$i] $read2s[$i] -i $mean_insertsize{$lib} $std_insertsize{$lib} > $fout_novo";

            $self->_run_cmd($cmd);
            push @novoaligns,$fout_novo;
            
            my $sort_prefix = "$prefix.$lib.$i";
            $cmd = $novosam_path . " -g $lib -f ".$self->platform." -l $lib $fout_novo | ". $samtools_path. " view -b -S - -t ". $ref_seq_idx .' | ' . $samtools_path." sort - $sort_prefix";
            $self->_run_cmd($cmd);
            push @bams, $sort_prefix.'.bam';
            push @bams2remove, $sort_prefix.'.bam';
        }
    
        if ($#bams>0) {
            #TODO using gmt command modules
            $cmd = $samtools_path ." merge $prefix.$lib.bam ". join(' ', @bams);
            $self->_run_cmd($cmd);
            push @bams2remove, "$prefix.$lib.bam";
        }
        else {
            #`mv $bams[0] $prefix.$lib.bam`;
            rename $bams[0], "$prefix.$lib.bam";
        }

        $cmd = $samtools_path." rmdup $prefix.$lib.bam $prefix.$lib.rmdup.bam";
        $self->_run_cmd($cmd);
        push @librmdupbams, "$prefix.$lib.rmdup.bam";
    }

    my $header_file = $prefix . '.header';
    my $header = Genome::Sys->open_file_for_writing($header_file) or die "fail to open $header_file for writing\n";
    for my $line (keys %headerline) {
        $header->print("$line\n");
    }
    $header->close;

    my $cmd = $samtools_path . " merge -h $header_file $prefix.novo.rmdup.bam ". join(' ', @librmdupbams);
    $self->_run_cmd($cmd);
    
    my $out_file = "$prefix.novo.cfg";

    my $novo_cfg = Genome::Sys->open_file_for_writing($out_file) or die "failed to open $out_file for writing\n";
    for my $lib (keys %fastqs) {
        $novo_cfg->printf("map:$prefix.novo.rmdup.bam\tmean:%s\tstd:%s\treadlen:%s\tsample:%s\texe:samtools view\n",$mean_insertsize{$lib},$std_insertsize{$lib},$readlens{$lib},$lib);
    }
    $novo_cfg->close;

    unlink (@bams2remove, @librmdupbams, @novoaligns, $header_file);
    #unlink glob($self->_temp_staging_directory."/*.bam");   #In case leftover bam

    my $bd_out_hq_filtered = $self->pass_staging_output;
    my $bd_out_lq_filtered = $self->fail_staging_output;
    my $bd_in_hq           = $self->detector_directory .'/svs.hq';  #DV2::Filter does not have _sv_base_name preset

    my $bd_path = $self->breakdancer_path;

    unless (-s $out_file) {
        $self->error_message("novo.cfg file $out_file is not valid");
        die;
    }

    $cmd = $bd_path . ' -t '. $out_file .' > '. $bd_out_hq_filtered;
    $self->_run_cmd($cmd);

    #rename $bd_out_hq, $bd_out_hq_filtered;

    my $bd_in_hq_fh  = Genome::Sys->open_file_for_reading($bd_in_hq) or die "Failed to open $bd_in_hq for reading\n";
    my $bd_out_hq_fh = Genome::Sys->open_file_for_reading($bd_out_hq_filtered) or die "Failed to open $bd_out_hq_filtered for reading\n";
    my $bd_out_lq_fh = Genome::Sys->open_file_for_writing($bd_out_lq_filtered) or die "Failed to open $bd_out_lq_filtered for writing\n";

    my %filter_match;

    while (my $line = $bd_out_hq_fh->getline) {
        next if $line =~ /^#/;
        my $match = _get_match_key($line);
        $filter_match{$match} = 1;
    }

    while (my $l = $bd_in_hq_fh->getline) {
        next if $l =~ /^#/;
        my $match = _get_match_key($l);
        $bd_out_lq_fh->print($l) unless exists $filter_match{$match};
    }

    $bd_in_hq_fh->close;
    $bd_out_hq_fh->close;
    $bd_out_lq_fh->close;

    return 1;
}


sub _validate_output {
    my $self = shift;

    unless(-d $self->output_directory){
        die $self->error_message("Could not validate the existence of output_directory");
    }
    
    my @files = glob($self->output_directory."/svs.hq");
    unless (@files) {
        die $self->error_message("Failed to get svs.hq");
    }
    return 1;
}


sub _get_match_key {
    my $line = shift;
    my @columns = split /\s+/, $line;
    #compare chr1 pos1 chr2 pos2 sv_type 5 columns
    my $match = join '-', $columns[0], $columns[1], $columns[3], $columns[4], $columns[6];
    return $match;
}


sub _run_cmd {
    my ($self, $cmd) = @_;
    
    unless (Genome::Sys->shellcmd(cmd => $cmd)) {
        $self->error_message("Failed to run $cmd");
        die $self->error_message;
    }
    return 1;
}

sub _create_bed_file {
    return 1;
}


1;
