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
    ],
};

sub help_brief {
    'Tool to run Error correction program EulerEc.pl',
}

sub execute {
    my $self = shift;

    $self->_init;

    #temp dir to run Euler
    my $euler_dir = Genome::Sys->base_temp_directory;
    $self->status_message("Running EulerEC in $euler_dir");

    #input reader from sx cmd
    my $reader = $self->_input;
    if ( not $reader ) {
        $self->error_message("Failed to get reader for input file");
    }

    #Input file for Euler
    my $euler_fasta = 'euler.fasta';
    my $euler_input_file = $euler_dir.'/'.$euler_fasta;
    unlink $euler_input_file, $euler_input_file.'.qual', $euler_input_file.'.report';
    my $euler_input_writer = Genome::Model::Tools::Sx::PhredWriter->create(
        file => $euler_input_file,
        qual_file => $euler_input_file.'.qual',
    );
    if ( not $euler_input_writer ) {
        $self->error_message("Failed to create Euler input writer");
        return;
    }
    while ( my $seqs = $reader->read ) {
        for my $seq ( @$seqs ) {
            $euler_input_writer->write( $seq );
        }
    }

    #build command
    my $cmd = 'EUSRC=/gsc/pkg/bio/euler/euler-sr-ec-2.0.2 MACHTYPE=x86_64 '; #set env
    $cmd .= 'EulerEC.pl '.$euler_fasta.' '.$self->kmer_size.' -minMult '.$self->min_multi;
    $cmd .= ' -script' if $self->script;
    $cmd .= ' -verbose' if $self->verbose;
    $cmd .= ' -debug' if $self->debug;

    #run command
    my $cwd = cwd();
    $self->status_message("Switching to dir: $euler_dir to run EulerEC");
    chdir $euler_dir; #Euler creates file in cwd
    $self->status_message("Running EulerEc.pl with CMD: $cmd");
    my $rv = eval { Genome::Sys->shellcmd( cmd => $cmd ); };
    if (! $rv ) {
        $self->error_message("Failed to run EulerEc.pl with command: $cmd");
        return;
    }
    $self->status_message("Successfully ran EulerEc.pl");

    #check output dir/files
    if ( not -d $euler_dir.'/fixed' ) {
        $self->error_message("Could not find euler created fixed dir: ".$euler_dir.'/fixed');
        return;
    }
    my $euler_output_file = $euler_dir.'/fixed/'.$euler_fasta;
    if ( not -s $euler_output_file ) {
        $self->error_message("Could not find euler output file or file is zero size: $euler_output_file");
        return;
    }

    #create sx output
    my $euler_output_reader = Genome::Model::Tools::Sx::PhredReader->create(
        file => $euler_output_file,
        qual_file => $euler_input_file.'.qual', #no new qual file created by euler
    );

    #write temp intermediate fastq
    my $tmp_fastq = $euler_dir.'/euler.fastq';
    my $tmp_fastq_writer = Genome::Model::Tools::Sx::Writer->create(
        config => [ $tmp_fastq.':type=sanger' ],
    );
    while ( my $seqs = $euler_output_reader->read ) {
        $tmp_fastq_writer->write( [$seqs] );
    }
    
    #read tmp int fastq and write final
    my $tmp_reader = Genome::Model::Tools::Sx::Reader->create(
        config => [ $tmp_fastq.':type=sanger:cnt=2' ],
    );
    my $writer = $self->_output;
    while ( my $seqs = $tmp_reader->read ) {
        $writer->write( $seqs );
    }
    $self->status_message("Created Euler output: $euler_output_file");

    chdir $cwd; #return to build data dir
    $self->status_message("Switching back to dir: $cwd");

    return 1;
}

1;
