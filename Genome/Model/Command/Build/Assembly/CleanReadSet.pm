package Genome::Model::Command::Build::Assembly::CleanReadSet;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Build::Assembly::CleanReadSet {
    is => 'Genome::Model::EventWithReadSet',
    has => [
            in_sff_file => {via => 'prior_event', to => 'sff_file'},
            out_sff_file => {
                             calculate_from => ['in_sff_file'],
                             calculate => q|
                                 my $file = $in_sff_file;
                                 $file =~ s/\.sff$/_clean\.sff/;
                                 return $file;
                             |
                         },
            fasta_file => {
                           calculate_from => ['in_sff_file'],
                           calculate => q|
                               my $fasta_file = $in_sff_file;
                               $fasta_file =~ s/\.sff$/\.fna/;
                               return $fasta_file;
                           |
                       },
            qual_file => {
                          calculate_from => ['in_sff_file'],
                          calculate => q|
                               my $qual_file = $in_sff_file;
                               $qual_file =~ s/\.sff$/\.qual/;
                               return $qual_file;
                           |
                      },
            seq_clean_report => {
                                 calculate_from => ['fasta_file'],
                                 calculate => q|
                                     return $fasta_file .'.cln';
                                 |
                             },
            trim_file => {
                                 calculate_from => ['fasta_file'],
                                 calculate => q|
                                     return $fasta_file .'.trim';
                                 |
                             },
        ]
};

sub bsub_rusage {
    return '';
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

    #Need to dump fasta or convert from sff
    unless (-e $self->fasta_file) {
        my $fasta_converter = Genome::Model::Tools::454::SffInfo->create(
                                                                         sff_file => $self->in_sff_file,
                                                                         output_file => $self->fasta_file,
                                                                         params => '-s',
                                                                     );
        unless ($fasta_converter->execute) {
            $self->error_message("Failed to run fasta converter on event ". $self->id);
            return;
        }
    }

    unless (-e $self->seq_clean_report) {
        my $seq_clean = Genome::Model::Tools::454::SeqClean->create(fasta_file => $self->fasta_file);
        unless ($seq_clean->execute) {
            $self->error_message('Failed to run seq clean ');
            return;
        }
    }

    unless (-e $self->seq_clean_report) {
        $self->error_message('Can not find seqclean report '. $self->seq_clean_report .' or it is zero size');
        return;
    }
    unless (-e $self->trim_file) {
        my $reader = Genome::Utility::SeqCleanReport::Reader->create(file => $self->seq_clean_report);
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
    unless (-e $self->out_sff_file) {
        my $sfffile = Genome::Model::Tools::454::SffFile->create(
                                                                 in_sff_file => $self->in_sff_file,
                                                                 out_sff_file => $self->out_sff_file,
                                                                 params => '-i '. $self->trim_file .' -t '. $self->trim_file,
                                                             );
        unless ($sfffile->execute) {
            $self->error_message('Failed to output trimmed sff file '. $self->out_sff_file);
            return;
        }
    }
    return 1;
}

