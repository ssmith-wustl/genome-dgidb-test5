package Genome::InstrumentData::Command::Import::HmpSra;

use strict;
use warnings;
use Genome;
use Cwd;

class Genome::InstrumentData::Command::Import::HmpSra {
    is  => 'Command',
    has_input => [
        run_ids => { 
            is_many => 1, 
            doc => 'the SRR ids of the data',
        },
    ],
    doc => 'download an import short read archive HMP data',
};

sub execute {
    my $self = shift;
    
    my @srr_ids = $self->run_ids;
    $self->status_message("SRR ids are: @srr_ids");

    my $tmp = '/gscuser/jmartin/ttmp'; 
    #my $tmp = Genome::Utility::FileSystem->create_temp_directory();
    $self->status_message("Temp data is in $tmp");

    my $scripts_dir = __FILE__;
    $scripts_dir =~ s/.pm//;
    $self->status_message("Scripts are in: $scripts_dir");    

    my $outfile;
    my $errfile;
    my $cmd;

    # build the SRA index
    $outfile = $tmp . '/SRA-index.txt';
    $errfile = $outfile . '.err';
    $cmd = "cd $tmp; $scripts_dir/build_public_SRA_run_index.pl --reuse_files "
        . ' > ' . $outfile 
        . ' 2> ' . $errfile;        
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        output_files => [$outfile,$errfile],
        skip_if_output_is_present => 1,
    );

    return 1;
}

1;

