package Genome::Data::Comparer_v2;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant::Tgi;
use Genome::Data::Converter;
use base 'Genome::Data::Converter';
use Clone qw(clone);

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
            $self->compare_all($object, $other_object, $to_writer_same, $to_writer_different_1, $to_writer_different_2);
            $object = $from_reader->next;
            $other_object = $from_reader2->next;
        }

    }

    return 1;
}

sub compare_all {
    my ($self, $object, $other_object, $to_writer_same, $to_writer_different_1, $to_writer_different_2) = @_;
    
    #sort the annotations by transcript
    my @sorted_annotations_1 = sort by_transcript @{$object->transcript_annotations};
    my @sorted_annotations_2 = sort by_transcript @{$other_object->transcript_annotations};

    #for each annotation, compare the trv_type
    my $count1 = 0;
    my $count2 = 0;
    while ($count1 < scalar @sorted_annotations_1 and $count2 < scalar @sorted_annotations_2) {
        if ($sorted_annotations_1[$count1]->{"transcript_name"} eq $sorted_annotations_2[$count2]->{"transcript_name"}) {
            my $new_object_1 = Genome::Data::Variant::AnnotatedVariant->create(
                chrom => $object->chrom,
                start => $object->start,
                end => $object->end,
                reference_allele => $object->reference_allele,
                alt_alleles => $object->alt_alleles,
                type => $object->type,
                transcript_annotations => [$sorted_annotations_1[$count1]]
            );
            if ($sorted_annotations_1[$count1]->{"trv_type"} eq $sorted_annotations_2[$count2]->{"trv_type"}) {
                #annotation is the same
                $to_writer_same->write($new_object_1);
            }
            else {
                #annotation is different
                my $new_object_2 = Genome::Data::Variant::AnnotatedVariant->create(
                    chrom => $other_object->chrom,
                    start => $other_object->start,
                    end => $other_object->end,
                    reference_allele => $other_object->reference_allele,
                    alt_alleles => $other_object->alt_alleles,
                    type => $other_object->type,
                    transcript_annotations => [$sorted_annotations_2[$count2]]
                );
                $to_writer_different_1->write($new_object_1);
                $to_writer_different_2->write($new_object_2);
            }
            $count1++;
            $count2++;
        }
        elsif ($sorted_annotations_1[$count1]->{"transcript_name"} lt $sorted_annotations_2[$count2]->{"transcript_name"}) {
            #transcript is annotated in 1 but not in 2
            $count1++;
        }
        elsif ($sorted_annotations_1[$count1]->{"transcript_name"} gt $sorted_annotations_2[$count2]->{"transcript_name"}) {
            #transcript is annotated in 2 but not in 1
            $count2++;
        }
    }
    while ($count1 < scalar @sorted_annotations_1) {
        #transcript is annotated in 1 but not in 2
        $count1++;
    }
    while ($count2 < scalar @sorted_annotations_2) {
        #transcript is annotated in 2 but not in 1
        $count2++;
    }
}

sub by_transcript {
    return $a->{"transcript_name"} cmp $b->{"transcript_name"};
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

