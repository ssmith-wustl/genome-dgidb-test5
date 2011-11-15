package Genome::Data::Comparer;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant::Tgi;
use Genome::Data::Converter;
use base 'Genome::Data::Converter';

sub create {
    my ($class, %params) = @_;
    my $to_file_different_1 = delete($params{"to_file_different_1"});
    my $to_file_different_2 = delete($params{"to_file_different_2"});
    my $from_file2 = delete($params{"from_file2"});

    my $self = $class->SUPER::create(%params);
    $self->_to_writer_different_1($to_file_different_1);
    $self->_to_writer_different_2($to_file_different_2);
    $self->_from_reader2($from_file2);
    return(bless($self, $class));
}

sub _to_writer_different_1 {
    my $self = shift;
    unless ($self->{_to_writer_different_1}) {
        my $file = shift;
        my $writer = Genome::Data::IO::Writer->create(
            file=> $file,
            format=> $self->to_format,
        );
        $self->{_to_writer_different_1} = $writer;
    }
    return $self->{_to_writer_different_1};
}

sub _to_writer_different_2 {
    my $self = shift;
    unless ($self->{_to_writer_different_2}) {
        my $file = shift;
        my $writer = Genome::Data::IO::Writer->create(
            file=> $file,
            format=> $self->to_format,
        );
        $self->{_to_writer_different_2} = $writer;
    }
    return $self->{_to_writer_different_2};
}

sub _from_reader2 {
    my $self = shift;
    unless ($self->{_from_reader2}) {
        my $file = shift;
        my $reader = Genome::Data::IO::Reader->create(
            file => $file,
            format => $self->from_format,
        );
        $self->{_from_reader2} = $reader;
    }
    return $self->{_from_reader2};
}

sub convert_all {
    my $self = shift;
    my $from_reader = $self->_from_reader;
    my $from_reader2 = $self->_from_reader2;
    my $to_writer_same = $self->_to_writer;
    my $to_writer_different_1 = $self->_to_writer_different_1;
    my $to_writer_different_2 = $self->_to_writer_different_2;
    my $object = $from_reader->next;
    my $other_object = $from_reader2->next;

    while($object || $other_object) {
        if (!$object) {
            while ($other_object) {
                #$to_writer_different_2->write($other_object);
                $other_object = $from_reader2->next;
            }
            return 1;
        }
        elsif (!$other_object) {
            while ($object) {
                #$to_writer_different_1->write($object);
                $object = $from_reader->next;
            }
            return 1;
        }
        while($self->compare($object, $other_object) != 0) {
            if ($self->compare($object, $other_object) == -1) {
                #$to_writer_different_1->write($object);
                $object = $from_reader->next;
            }
            else {
                #$to_writer_different_2->write($other_object);
                $other_object = $from_reader2->next;
            }
            if (!$object) {
                while ($other_object) {
                    #$to_writer_different_2->write($other_object);
                    $other_object = $from_reader2->next;
                }
                return 1;
            }
            elsif (!$other_object) {
                while ($object) {
                    #$to_writer_different_1->write($object);
                    $object = $from_reader->next;
                }
                return 1;
            }
        }

        if ($object and $other_object) {
            if (#$object->transcript_annotations->[0]->{"gene_name"} eq 
                #$other_object->transcript_annotations->[0]->{"gene_name"} and
                $object->transcript_annotations->[0]->{"trv_type"} eq
                $other_object->transcript_annotations->[0]->{"trv_type"} ) {
                $to_writer_same->write($object);
            }

            else { 
                if ($object->transcript_annotations->[0]->{"trv_type"} eq "missense" or
                 $other_object->transcript_annotations->[0]->{"trv_type"} eq "missense" or
                 $other_object->transcript_annotations->[0]->{"trv_type"} =~ m/frame_shift/ or
                 $object->transcript_annotations->[0]->{"trv_type"} =~ m/frame_shift/) {
                $to_writer_different_1->write($object);
                $to_writer_different_2->write($other_object);
                }
            }
            $object = $from_reader->next;
            $other_object = $from_reader2->next;
        }

    }

    return 1;
}

sub compare() {
    my ($self, $obj1, $obj2) = @_;
if ($obj2->start == 22750583) {
    $DB::single = 1;
}
    if ($obj1->chrom eq $obj2->chrom) {
        if ($obj1->start == $obj2->start) {
            return 0;
        }
        elsif ($obj1->start < $obj2->start) {
            return -1;
        }
        else {
            return 1;
        }
    }
    elsif ($obj1->chrom lt $obj2->chrom) {
        return -1;
    }
    else {
        return 1;
    }
}

1;

