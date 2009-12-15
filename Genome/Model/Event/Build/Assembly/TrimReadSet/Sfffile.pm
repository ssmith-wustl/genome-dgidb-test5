package Genome::Model::Event::Build::Assembly::TrimReadSet::Sfffile;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::Assembly::TrimReadSet::Sfffile {
    is => 'Genome::Model::Event::Build::Assembly::TrimReadSet',
    has => [
            seqclean_report => { via => 'prior_event', },
        ]
};

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "trim the reads using sfffile based on the output of seqclean"
}

sub help_synopsis {
    return <<"EOS"
genome-model build reference-alignment trim-read-set sfffile ...
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $model = $self->model;
    my $instrument_data = $self->instrument_data;
    unless (-e $instrument_data->trimmed_sff_file) {
	my %trimmer_params = (
			      seqclean_report => $self->seqclean_report,
			      in_sff_file => $instrument_data->sff_file,
			      out_sff_file => $instrument_data->trimmed_sff_file,
			      version => $model->assembler_version,
			      version_subdirectory => $model->version_subdirectory,
                          );
        unless (Genome::Model::Tools::454::SffTrimWithSeqcleanReport->execute( %trimmer_params )) {
            $self->error_message("Failed to execute trim seq-clean tool with params:\n".
                                 Data::Dumper::Dumper(%trimmer_params));
            return;
        }
    }
    return 1;
}

