package Genome::Model::Command::Build::AmpliconAssembly::Assemble;

use strict;
use warnings;

use Genome;

require Genome::Model::Tools::PhredPhrap::ScfFile;
require Genome::Utility::FileSystem;

class Genome::Model::Command::Build::AmpliconAssembly::Assemble{
    is => 'Genome::Model::Event',
};

#< Subclassing...don't >#
sub _get_sub_command_class_name {
  return __PACKAGE__;
}

#< LSF >#
sub bsub_rusage {
    return "-R 'span[hosts=1]'";
}

#< Beef >#
sub execute {
    my $self = shift;

    my $amplicons = $self->build->get_amplicons
        or return;

    for my $amplicon ( @$amplicons ) {
        $self->_assemble_amplicon($amplicon)
            or return;
    }

    return 1;
}

sub _assemble_amplicon {
    my ($self, $amplicon) = @_;

    # Create SCF file
    my $scf_file = sprintf('%s/%s.scfs', $self->build->edit_dir, $amplicon->get_name);
    unlink $scf_file if -e $scf_file;
    my $scf_fh = Genome::Utility::FileSystem->open_file_for_writing($scf_file)
        or return;
    for my $scf ( @{$amplicon->get_reads} ) { 
        $scf_fh->print("$scf\n");
    }
    $scf_fh->close;

    unless ( -s $scf_file ) {
        $self->error_message("Error creating SCF file ($scf_file)");
        return;
    }

    # Create and run the Command
    my $command = Genome::Model::Tools::PhredPhrap::ScfFile->create(
        directory => $self->build->data_directory,
        assembly_name => $amplicon->get_name,
        scf_file => $scf_file,
    );
    #eval{ # if this fatals, we still want to go on
    $command->execute;
    #};
    #TODO write file for failed assemblies

    return 1;
}

1;

#$HeadURL$
#$Id$
