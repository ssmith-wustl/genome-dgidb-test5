package Genome::Model::Tools::Sx::EulerEc;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Cwd;

class Genome::Model::Tools::Sx::EulerEc {
    is => 'Genome::Model::Tools::Sx',
    has => [
        kmer_size => {
            is => 'Number',
            doc => 'Kmer size to use',
        },
        min_multi => {
            is => 'Number',
            doc => 'Minimum multiplicity to keep a k-mer (vertex) or (k+1)-mer (edge), depending on the stage of EULER.',
        },
        script => {
            is => 'Boolean',
            doc => 'Show output from subprocesses. Output is suppressed without this option.',
            is_optional => 1,
        },
        debug => {
            is => 'Boolean',
            doc => 'Run the debug version of the code, compiled by \'make debug\'.',
            is_optional => 1,
        },
        verbose => {
            is => 'Boolean',
            doc => 'Show output from subprocesses. Output is suppressed without this option.',
            is_optional => 1,
        },
        _tmp_pre_fwd_fastq => {
            is_transient => 1, is_optional => 1,
        },
        _tmp_pre_rev_fastq => {
            is_transient => 1, is_optional => 1,
        },
        _tmp_post_fwd_fastq => {
            is_transient => 1, is_optional => 1,
        },
        _tmp_post_rev_fastq => {
            is_transient => 1, is_optional => 1,
        },
    ],
};

sub help_brief {
    'Tool to run Error correction program EulerEc.pl',
}

sub execute {
    my $self = shift;

    $self->_init;
    my $cwd = cwd();

    #temp dir to run EulerEC
    my $euler_dir = Genome::Sys->base_temp_directory;
    $self->status_message("Running EulerEC in $euler_dir");

    #input reader from sx cmd
    my $reader = $self->_input;
    if ( not $reader ) {
        $self->error_message("Failed to get reader for input file");
    }

    #split bam into fwd/rev fastqs
    my $fwd_fastq = 'euler.pre.fwd.fastq';
    my $rev_fastq = 'euler.pre.rev.fastq';
    my $fwd_fastq_file = $euler_dir.'/'.$fwd_fastq;
    my $rev_fastq_file = $euler_dir.'/'.$rev_fastq;
    my $fwd_rev_writer = Genome::Model::Tools::Sx::Writer->create(
        config => [$fwd_fastq_file.':name=fwd:type=sanger',$rev_fastq_file.':name=rev:type=sanger'],
    );
    while ( my $seqs = $reader->read ) {
        $fwd_rev_writer->write( $seqs );
    }
    unless ( -s $fwd_fastq_file ) {
        $self->error_message("Failed to create fwd fastq file or file is zero size: ".$fwd_fastq_file);
        return;
    }
    $self->_tmp_pre_fwd_fastq( $fwd_fastq_file );
    unless ( -s $rev_fastq_file ) {
        $self->error_message("Failed to create rev fastq file or file is zero size: ".$rev_fastq_file);
        return;
    }
    $self->_tmp_pre_rev_fastq( $rev_fastq_file );

    #run EulerEC separately on fwd and rev fastqs
    for my $type ( qw/ fwd rev / ) {
        Genome::Sys->create_directory( $euler_dir.'/'.$type );
        #sx reader
        my $file_method = '_tmp_pre_'.$type.'_fastq';
        if ( not -s $self->$file_method ) {
            $self->error_message("Failed to find file or file is zero size or did not get set: ".$self->$file_method);
            return;
        }
        my $reader = Genome::Model::Tools::Sx::Reader->create(
            config => [ $self->$file_method ],
        );
        if ( not $reader ) {
            $self->error_message("Failed to create sx reader for file: ".$self->$file_method);
            return;
        }
        #sx fasta writer
        my $fasta_name = 'euler.pre.'.$type.'.fasta';
        my $fasta_file = $euler_dir."/$type/".$fasta_name;
        my $writer = Genome::Model::Tools::Sx::PhredWriter->create(
            file => $fasta_file,
            qual_file => $fasta_file.'.qual',
        );
        if ( not $writer ) {
            $self->error_message("Failed to create writer to write EulerEC input fasta file");
            return;
        }
        while ( my $seqs = $reader->read ) {
            $writer->write( @$seqs[0] );
        }
        #build EulerEC command
        my $cmd = 'EUSRC=/gsc/pkg/bio/euler/euler-sr-ec-2.0.2 MACHTYPE=x86_64 '; #set env
        $cmd .= 'EulerEC.pl '.$fasta_name.' '.$self->kmer_size.' -minMult '.$self->min_multi;
        $cmd .= ' -script' if $self->script;
        $cmd .= ' -verbose' if $self->verbose;
        $cmd .= ' -debug' if $self->debug;
        #run command
        $self->status_message("Running EulerEc.pl with CMD: $cmd");
        chdir $euler_dir.'/'.$type; #Euler output files to cwd
        $self->status_message("Switching to $euler_dir/".$type." to run Euler");
        ### THS IS DOESN'T WORK WITH STRINGS OF MULTIPLE SX CMDS WILL LOOK INTO IT ###
        #my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
        #if (! $rv ) {
        #    $self->error_message("Failed to run EulerEc.pl with command: $cmd");
        #    return;
        #}
        my $rv = `$cmd`;
        chdir $cwd;
        $self->status_message("EulerEC output message:\n$rv");
        $self->status_message("Switching back to original dir: $cwd");
        #check EulerEC output files
        if ( not -d $euler_dir."/$type/fixed" ) {
            $self->error_message("Euler did not create fixed dir for run: ".$euler_dir."/$type/fixed");
            return;
        }
        if ( not -s $euler_dir."/$type/fixed/$fasta_name" ) {
            $self->error_message("Failed to find Euler output file or file is zero size: ".$euler_dir."/$type/fixed/$fasta_name");
            return;
        }
        $self->status_message("Successfully ran EulerEc");
        #writer post EulerEC fwd/rev fastq
        my $post_reader = Genome::Model::Tools::Sx::PhredReader->create(
            file => $euler_dir.'/'.$type.'/fixed/'.$fasta_name,
            qual_file => $euler_dir.'/'.$type.'/'.$fasta_name.'.qual',
        );
        my $post_file = $euler_dir.'/euler.post.'.$type.'.fastq';
        my $post_writer = Genome::Model::Tools::Sx::Writer->create(
            config => [ $post_file ],
        );
        if ( not $post_writer ) {
            $self->error_message("Failed to create post EulerEC fastq writer");
            return;
        }
        while ( my $seq = $post_reader->read ) {
            $post_writer->write([$seq]);
        }
        if ( not -s $post_file ) {
            $self->error_message("Failed to create post EulerEC fastq file: $post_file");
            return;
        }
        my $post_file_method = '_tmp_post_'.$type.'_fastq';
        $self->$post_file_method( $post_file );
    }

    #writer final fastq
    my $final_reader = Genome::Model::Tools::Sx::Reader->create(
        config => [$self->_tmp_post_fwd_fastq.':type=sanger',$self->_tmp_post_rev_fastq.':type=sanger'],
    );
    my $writer = $self->_output;
    while ( my $seqs = $final_reader->read ) {
        $writer->write( $seqs );
    }
    
    return 1;
}

1;
