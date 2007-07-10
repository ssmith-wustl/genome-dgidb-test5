#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use ChromosomeAlignmentCollection qw(END_TOKEN MAX_READ_LENGTH INDEX_RECORD_SIZE);

use Test::More tests => 43;

# Remove the temp files that may have been laying around from a previous run
my @file_list = ('/tmp/testme_chr_24_aln.dat',
                 '/tmp/testme_chr_24_aln.ndx',
                 '/tmp/testme_chr_24_SORTED_aln.dat',
                 '/tmp/testme_chr_24_SORTED_aln.ndx',
                );
unlink @file_list;

my $unsorted = ChromosomeAlignmentCollection->new(file_prefix => '/tmp/testme_chr_24', 
                                                  mode => O_RDWR | O_CREAT);

ok($unsorted, "Created a new ChromosomeAlignmentCollection object");

my $fake_coords = [ # start, stop, last_alignment_number, number of alignments
                    [1, 32, END_TOKEN, 1],
                    [2, 33, END_TOKEN, 2],
                    [4, 35, END_TOKEN, 2],
                    [1, 32, 0, 1],
                    [2, 33, 1, 2], # * index 4
                    [4, 35, 2, 2], # * index 5
                    [1, 32, 3, 1], # * index 6
                   ];

{
    my $read_num = 0;
    foreach my $fake ( @$fake_coords ) {
        my $alignment_record = { # last_alignment_number   => $fake->[2],  # The module should fill this in
                                 read_number             => $read_num++,
                                 probability             => 1,
                                 length                  => 32,
                                 orientation             => 1,
                                 number_of_alignments    => $fake->[0],
                                 ref_and_mismatch_string => chr(11) x MAX_READ_LENGTH,
                               };

        ok($unsorted->add_alignments_for_position($fake->[0], [$alignment_record]), "Wrote an alignment record for position ".$fake->[0]);
    }
}

ok($unsorted->flush(), "Flushed the unsorted file's handles");

{
# Check that the index file looks OK by reading the data by hand
    my @expected_index_data = (END_TOKEN, 6,4,END_TOKEN, 5);
    my $prev_irs = $/;
    $/ = undef;
    my $fh = $unsorted->index_fh;
    $fh->seek(0,0);
    my $all_index_data = <$fh>;
    my @got_index_data = unpack("Q*",$all_index_data);

    is(scalar @got_index_data, scalar @expected_index_data, "Read the correct number of index items");
    for (my $i = 1; $i < @expected_index_data; $i++) {
        is($got_index_data[$i], $expected_index_data[$i], "Index data at position $i is correct read by hand");
    }
    $/ = $prev_irs;

# Check that the index file looks OK using the API
    for (my $i = 1; $i< @expected_index_data; $i++) {
        my $index_data = $unsorted->_read_index_record_at_position($i);
        is($index_data, $expected_index_data[$i], "Index data at position $i is correct though the API");
    }
}

# Check that the data file looks ok
{
    my @expected_ptrs = ( [END_TOKEN],
                          [ 3, 0, END_TOKEN],
                          [ 1, END_TOKEN],
                          [ END_TOKEN ],
                          [ 2, END_TOKEN],
                        );
    for (my $i = 1; $i <= 4; $i++) {
        my $alignment_num = $unsorted->_read_index_record_at_position($i);
        my $count = 0;
        do {
            my $record = $unsorted->get_alignment_node_for_alignment_num($alignment_num);

            next unless $record;
            is($record->{'last_alignment_number'}, $expected_ptrs[$i]->[$count], "last alignment number for pos $i record $count is correct");
            $alignment_num = $record->{'last_alignment_number'};
            $count++;
        } while ($alignment_num != END_TOKEN);
    }
}

my $sorted = ChromosomeAlignmentCollection->new(file_prefix => '/tmp/testme_chr_24_SORTED',
                                                mode => O_RDWR | O_CREAT);

ok($sorted, "Created a new ChromosomeAlignmentCollection to contain the sorted data");

ok($sorted->merge($unsorted), "Calling merge() with the unsorted data");

# Check that the sorted index looks ok
{
    my @expected_index_data = (0, 2,4,END_TOKEN, 6);

    my $prev_irs = $/;
    $/ = undef;
    my $fh = $sorted->index_fh;
    $fh->seek(0,0);
    my $all_index_data = <$fh>;
    my @got_index_data = unpack("Q*",$all_index_data);

    is(scalar @got_index_data, scalar @expected_index_data, "Read the correct number of index items");
    for (my $i = 1; $i < @expected_index_data; $i++) {
        is($got_index_data[$i], $expected_index_data[$i], "Index data at position $i is correct read by hand");
    }
    $/ = $prev_irs;

    # And again through the API

    for (my $i = 1; $i< @expected_index_data; $i++) {
        my $index_data = $sorted->_read_index_record_at_position($i);
        is($index_data, $expected_index_data[$i], "Index record at position $i is ok");
    }
}

# Check that the sorted data looks ok
{
    my @expected_ptrs = ( [END_TOKEN],
                          [ 1, 0, END_TOKEN],
                          [ 3, END_TOKEN],
                          [ END_TOKEN ],
                          [ 5, END_TOKEN],
                        );
    for (my $i = 1; $i <= 4; $i++) {
        my $alignment_num = $sorted->_read_index_record_at_position($i);
        my $count = 0;
        do {
            my $record = $sorted->get_alignment_node_for_alignment_num($alignment_num);

            next unless $record;
            is($record->{'last_alignment_number'}, $expected_ptrs[$i]->[$count], "last alignment number for pos $i record $count is correct");
            $alignment_num = $record->{'last_alignment_number'};
            $count++;
        } while ($alignment_num != END_TOKEN);
    }
}

# Remove the unsorted and sorted files
unlink @file_list;
