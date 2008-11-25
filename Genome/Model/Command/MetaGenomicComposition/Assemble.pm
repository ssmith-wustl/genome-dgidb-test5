package Genome::Model::Command::MetaGenomicComposition::Assemble;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Genome::Model::Tools::PhredPhrap::ScfFile;

class Genome::Model::Command::MetaGenomicComposition::Assemble {
    is => 'Genome::Model::Command::MetaGenomicComposition',
};

#<>#
sub help_brief {
    return 'Assembles MGC models as sets of reads from a single subclone';
}

sub help_detail {
    return help_brief();
}

sub sub_command_sort_position {
    return 10;
}

#<>#
sub execute {
    my $self = shift;

    $self->_verify_mgc_model
        or return;
    
    my $subclones = $self->model->subclones_and_traces_for_assembly
        or return;

    $self->status_message( 
        printf(
            "<=== Running %d assemblies for model (%s <ID: %s>) ===>\n",
            scalar(keys %$subclones),
            $self->model->name,
            $self->model->id,
        )
    );

    while ( my ($subclone, $scfs) = each %$subclones ) {
        $self->status_message("<=== Assembling $subclone ===>");
        my $scf_file = sprintf('%s/%s.scfs', $self->model->consed_directory->edit_dir, $subclone);
        unlink $scf_file if -e $scf_file;
        my $scf_fh = IO::File->new("> $scf_file")
            or ($self->error_message("Can't open file ($scf_file) for writing: $!") and return);
        for my $scf ( @$scfs ) { 
            $scf_fh->print("$scf\n");
        }
        $scf_fh->close;

        unless ( -s $scf_file ) {
            $self->error_message("Error creating SCF file ($scf_file)");
            return;
        }

        my $command = Genome::Model::Tools::PhredPhrap::ScfFile->create(
            directory => $self->model->data_directory,
            assembly_name => $subclone,
            scf_file => $scf_file,
        );

        #eval{ # if this fatals, we still want to go on
            $command->execute;
            #};
        #FIXME cleanup of auxillary files used to create assembly - .scfs .phds .fasta etc?
        #FIXME create file of oriented fastas? if so remove the assemblies too?
    }

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
