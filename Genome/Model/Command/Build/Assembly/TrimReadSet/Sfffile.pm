package Genome::Model::Command::Build::Assembly::TrimReadSet::Sfffile;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Assembly::TrimReadSet::Sfffile {
    is => 'Genome::Model::Command::Build::Assembly::TrimReadSet',
    has => [
            seqclean_report => { via => 'prior_event', },
            in_sff_file     => {via => 'prior_event', to => 'sff_file'},
            sff_file => {
                         calculate_from => ['in_sff_file'],
                         calculate => q|
                                 my $file = $in_sff_file;
                                 $file =~ s/\.sff$/_clean\.sff/;
                                 return $file;
                             |
                     },
            trim_file => {
                                 calculate_from => ['in_sff_file'],
                                 calculate => q|
                                     my $file = $in_sff_file;
                                     $file =~ s/\.sff$/\.trim/;
                                     return $file;
                                 |
                             },
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

    unless (-e $self->trim_file && -e $self->sff_file) {
        my $sfffile_trim = Genome::Model::Tools::454::SffTrimWithSeqcleanReport->create(
                                                                                        seqclean_report => $self->seqclean_report,
                                                                                        in_sff_file => $self->in_sff_file,
                                                                                        out_sff_file => $self->sff_file,
                                                                                        trim_file =>  $self->trim_file,
                                                                                    );
        unless ($sfffile_trim->execute) {
            $self->error_message('Failed to execute genome-model tool '. $sfffile_trim->class_name);
            return;
        }
    }
    return 1;
}

