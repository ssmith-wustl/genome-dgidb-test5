package Genome::Model::Tools::454::SffTrimWithSeqcleanReport;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::454::SffTrimWithSeqcleanReport {
    is => ['Genome::Model::Tools::454'],
    has => [
            seqclean_report => {
                                is => 'string',
                                doc => 'a file path to the seqclean report file',
                                is_input => 1,
                    },
            in_sff_file => {
                            is => 'string',
                            doc => 'a file path to the input sff file',
                            is_input => 1,
                     },
            trim_file => {
                          is_output => 1,
                          calculate_from => ['in_sff_file'],
                          calculate => q|
                                     my $file = $in_sff_file;
                                     $file =~ s/\.sff$/\.trim/;
                                     return $file;
                                 |
                      },
            out_sff_file => {
                             is => 'string',
                             doc => 'a file path to the output sff file',
                             is_output => 1,
                         }
        ],
};

sub help_brief {
    "a tool to trim reads based on the output of seqclean",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt 454 sff-trim-with-seqclean-report   ...
EOS
}

sub help_detail {
    return <<EOS
This tool converts the seqclean report to a sfffile trim file format.
The trim file is then used to trim the reads and exclude reads not listed in the trim file.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    unless ($self->arch_os =~ /64/) {
        $self->error_message('This genome-model tool '. $self->command_name .' will only run on 64-bit');
        return;
    }
    unless (-e $self->seqclean_report) {
        die 'Seqclean report file '. $self->seqclean_report .' does not exist';
    }
    unless (-e $self->in_sff_file) {
        die 'Input sff file '. $self->in_sff_file .' does not exist';
    }
    if (-e $self->trim_file) {
        die 'sfffile trim file '. $self->trim_file .' already exists';
    }
    if (-e $self->out_sff_file) {
        die 'Output sff file '. $self->out_sff_file .' already exists';
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $reader = Genome::Utility::SeqcleanReport::Reader->create(file => $self->seqclean_report);
    unless ($reader) {
        $self->error_message('Failed to create seqclean report reader for file'. $self->seqclean_report);
        return;
    }
    my $writer = Genome::Utility::454TrimFile::Writer->create(file => $self->trim_file);
    unless ($writer) {
        $self->error_message('Failed to create sfffile trim file writer for file '. $self->trim_file);
        return;
    }
    while (my $record = $reader->next) {
        if ($record->{trash_code} && $record->{trash_code} ne '') {
            next;
        }
        $writer->write_record($record);
    }
    $writer->close;
    $reader->close;

    my $sfffile = Genome::Model::Tools::454::Sfffile->create(
                                                             in_sff_file => $self->in_sff_file,
                                                             out_sff_file => $self->out_sff_file,
                                                             params => '-i '. $self->trim_file .' -t '. $self->trim_file,
                                                         );
    unless ($sfffile->execute) {
        $self->error_message('Failed to output trimmed sff file '. $self->out_sff_file);
        return;
    }

    return 1;
}


1;

