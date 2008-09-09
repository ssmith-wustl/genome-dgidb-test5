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
    "assemble a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
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

    unless (-e $self->trim_file) {
        my $reader = Genome::Utility::SeqcleanReport::Reader->create(file => $self->seqclean_report);
        my $writer = Genome::Utility::454TrimFile::Writer->create(file => $self->trim_file);
        while (my $record = $reader->next) {
            if ($record->{trash_code} && $record->{trash_code} ne '') {
                next;
            }
            $writer->write_record($record);
        }
        $writer->close;
        $reader->close;
    }
    unless (-e $self->sff_file) {
        my $sfffile = Genome::Model::Tools::454::Sfffile->create(
                                                                 in_sff_file => $self->in_sff_file,
                                                                 out_sff_file => $self->sff_file,
                                                                 params => '-i '. $self->trim_file .' -t '. $self->trim_file,
                                                             );
        unless ($sfffile->execute) {
            $self->error_message('Failed to output trimmed sff file '. $self->sff_file);
            return;
        }
    }
    return 1;
}

