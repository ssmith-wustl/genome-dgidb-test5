#$Id$

package PAP::Command::Hmmpfam;

use strict;
use warnings;

use Workflow;

use English;
use File::Basename;
use File::chdir;
use File::Temp;
use File::Slurp;
use IO::File;
use IPC::Run;
use Carp;

class PAP::Command::Hmmpfam {
    is  => ['PAP::Command'],
    has => [
        hmmdirpath => {
            is  => 'SCALAR',
            doc => '',
        },
        hmm_database => {
            is  => 'SCALAR',
            doc => 'hmmpfam database file',
        },
        fasta_dir => {
            is  => 'SCALAR',
            doc => 'directory containing fasta files',
        },
        sequence_names => {
            is  => 'ARRAY',
            doc => 'a list of sequence names for running hmmpfam on',
        },
        success => {
            is          => 'SCALAR',
            doc         => 'success flag',
            is_optional => 1,
        },
    ],
};

operation PAP::Command::Hmmpfam {
    input     => [  'hmmdirpath', 'hmm_database', 'fasta_dir', 'sequence_names' ],
    output    => ['success'],
    lsf_queue => 'long',
    lsf_resource => '-R "rusage[tmp=100]" ',
};

sub sub_command_sort_position {10}

sub help_brief
{
    "Run run the BER hmmpfam step";
}

sub help_synopsis
{
    return <<"EOS"
EOS
}

sub help_detail
{
    return <<"EOS"
Need documenation here.
EOS
}

sub execute
{

    my $self = shift;

    {

#        local $CWD = $self->workdir();
        foreach my $seqname ( @{ $self->sequence_names } )
        {
            my $file = $self->fasta_dir . "/" . $seqname;

            my @hmmpfam_command
                = ( 'hmmpfam', '--cpu', '1', $self->hmm_database, $file, );

            my ( $hmmpfam_stdout, $hmmpfam_stderr );
            my $hmmpfam_outfile
                = $self->hmmdirpath . "/" . $seqname . ".hmmpfam";
            IPC::Run::run(
                \@hmmpfam_command, 
                '<',  
                \undef, 
                '>', \$hmmpfam_stdout,  
                '2>', \$hmmpfam_stderr,
                )
                || croak "ber hmmpfam failed: $hmmpfam_stderr : $CHILD_ERROR";
            write_file( $hmmpfam_outfile, $hmmpfam_stdout );
        }
    }
    $self->success(1);
    return 1;

}

1;
